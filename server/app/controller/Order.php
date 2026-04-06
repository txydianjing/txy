<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use app\model\Order as OrderModel;
use think\facade\Db;
use think\facade\Cache;

class Order extends BaseController
{
    private $feeConfig = [
        'gold' => 0.5,
        'silver' => 1.0,
        'bronze' => 2.0
    ];
    
    private $silverDailyExtra = 0.5;
    
    private function getUserId()
    {
        $token = $this->request->header('Authorization');
        $token = str_replace('Bearer ', '', $token);
        return Cache::get('token_' . $token);
    }
    
    private function getUser()
    {
        $userId = $this->getUserId();
        return $userId ? UserModel::find($userId) : null;
    }
    
    public function create()
    {
        $user = $this->getUser();
        if (!$user || !in_array($user->level, [1,2,3,4])) {
            return json(['code' => 403, 'msg' => '请先登录']);
        }
        
        $data = $this->request->post(['service_type', 'game_map', 'price', 'remark']);
        
        $order = OrderModel::create([
            'order_sn' => $this->generateOrderSn(),
            'user_id' => $user->id,
            'service_type' => $data['service_type'],
            'game_map' => $data['game_map'] ?? '',
            'price' => $data['price'],
            'status' => 0,
            'remark' => $data['remark'] ?? '',
            'expire_time' => date('Y-m-d H:i:s', strtotime('+5 minutes')),
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        $user->balance -= $data['price'];
        $user->save();
        
        return json(['code' => 200, 'data' => $order, 'msg' => '下单成功']);
    }
    
    public function getAvailableOrders()
    {
        $orders = OrderModel::where('status', 0)
            ->order('create_time', 'asc')
            ->select();
            
        foreach ($orders as &$order) {
            $order['is_expired'] = strtotime($order['expire_time']) < time();
        }
        
        return json(['code' => 200, 'data' => $orders]);
    }
    
    public function grab()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        if ($user->level == 5) {
            $captchaToken = $this->request->post('captcha_token');
            if (!$this->verifySlideCaptcha($captchaToken)) {
                return json(['code' => 400, 'msg' => '请完成滑动验证']);
            }
        }
        
        if (!in_array($user->level, [1,3])) {
            return json(['code' => 403, 'msg' => '您不是打手，无法接单']);
        }
        
        $orderId = $this->request->post('order_id');
        
        $order = OrderModel::where('id', $orderId)->lock(true)->find();
        
        if (!$order || $order->status != 0) {
            return json(['code' => 400, 'msg' => '订单不存在或已被抢']);
        }
        
        $playerRank = $user->player_rank;
        $fee = $this->feeConfig[$playerRank];
        $playerIncome = $order->price - $fee;
        
        if ($playerRank == 'silver') {
            $this->addDailyExtra($user->id);
        }
        
        $order->player_id = $user->id;
        $order->player_rank_at_grab = $playerRank;
        $order->platform_fee = $fee;
        $order->player_income = $playerIncome;
        $order->status = 1;
        $order->start_time = date('Y-m-d H:i:s');
        $order->save();
        
        Db::name('order_log')->insert([
            'order_id' => $orderId,
            'action' => '接单',
            'user_id' => $user->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '接单成功', 'data' => ['fee' => $fee, 'income' => $playerIncome]]);
    }
    
    public function complete()
    {
        $user = $this->getUser();
        $orderId = $this->request->post('order_id');
        
        $order = OrderModel::where('id', $orderId)
            ->where('player_id', $user->id)
            ->whereIn('status', [1,4])
            ->find();
        
        if (!$order) {
            return json(['code' => 400, 'msg' => '订单不存在']);
        }
        
        $order->status = 2;
        $order->complete_time = date('Y-m-d H:i:s');
        $order->save();
        
        $user->balance += $order->player_income;
        $user->total_orders += 1;
        $user->total_earned += $order->player_income;
        $user->save();
        
        if ($user->player_rank == 'silver') {
            $this->recordDailyExtra($user->id);
        }
        
        return json(['code' => 200, 'msg' => '订单完成，收入已入账']);
    }
    
    public function cancel()
    {
        $user = $this->getUser();
        $orderId = $this->request->post('order_id');
        $reason = $this->request->post('reason', '');
        
        $order = OrderModel::where('id', $orderId)
            ->where('player_id', $user->id)
            ->where('status', 1)
            ->find();
        
        if (!$order) {
            return json(['code' => 400, 'msg' => '订单不存在']);
        }
        
        $order->status = 3;
        $order->cancel_reason = $reason;
        $order->save();
        
        $boss = UserModel::find($order->user_id);
        $boss->balance += $order->price;
        $boss->save();
        
        return json(['code' => 200, 'msg' => '退单成功']);
    }
    
    public function save()
    {
        $user = $this->getUser();
        $orderId = $this->request->post('order_id');
        
        $order = OrderModel::where('id', $orderId)
            ->where('player_id', $user->id)
            ->where('status', 1)
            ->find();
        
        if (!$order) {
            return json(['code' => 400, 'msg' => '订单不存在']);
        }
        
        $order->status = 4;
        $order->save();
        
        return json(['code' => 200, 'msg' => '已暂存订单']);
    }
    
    public function applyTeam()
    {
        $user = $this->getUser();
        $orderId = $this->request->post('order_id');
        $targetPlayerId = $this->request->post('target_player_id');
        
        $order = OrderModel::find($orderId);
        if (!$order || $order->player_id != $user->id || $order->status != 2) {
            return json(['code' => 400, 'msg' => '只有已完成订单的打手可以申请组队']);
        }
        
        $players = UserModel::where('level', 3)
            ->where('status', 1)
            ->field('id, nickname, player_rank')
            ->select();
        
        if ($targetPlayerId) {
            $target = UserModel::find($targetPlayerId);
            if (!$target || $target->level != 3) {
                return json(['code' => 400, 'msg' => '目标打手不存在']);
            }
            Db::name('team_apply')->insert([
                'order_id' => $orderId,
                'player_id' => $user->id,
                'target_player_id' => $targetPlayerId,
                'create_time' => date('Y-m-d H:i:s')
            ]);
        } else {
            foreach ($players as $player) {
                Db::name('team_appl