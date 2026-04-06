<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Withdraw extends BaseController
{
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
    
    // 申请提现
    public function apply()
    {
        $user = $this->getUser();
        if (!$user || $user->level != 3) {
            return json(['code' => 403, 'msg' => '只有打手可以提现']);
        }
        
        $amount = $this->request->post('amount');
        $image = $this->request->file('image');
        
        if (!$amount || $amount <= 0) {
            return json(['code' => 400, 'msg' => '请输入正确金额']);
        }
        if ($amount > $user->balance) {
            return json(['code' => 400, 'msg' => '余额不足']);
        }
        if (!$image) {
            return json(['code' => 400, 'msg' => '请上传截图凭证']);
        }
        
        // 金牌打手：全天可申请；银牌/铜牌：8:00-20:00
        $currentHour = date('H');
        if ($user->player_rank != 'gold') {
            if ($currentHour < 8 || $currentHour >= 20) {
                return json(['code' => 400, 'msg' => '提现申请时间：每天8:00-20:00']);
            }
        }
        
        // 保存图片
        $savePath = 'uploads/withdraw/' . date('Ymd') . '/';
        $imageName = $user->id . '_' . time() . '.' . $image->extension();
        $image->move($savePath, $imageName);
        
        Db::name('withdraw')->insert([
            'user_id' => $user->id,
            'amount' => $amount,
            'image_url' => $savePath . $imageName,
            'status' => 0,
            'apply_time' => date('Y-m-d H:i:s')
        ]);
        
        $msg = $user->player_rank == 'gold' 
            ? '提现申请已提交，晚上8-9点统一打款' 
            : '提现申请已提交，请等待管理员处理';
        
        return json(['code' => 200, 'msg' => $msg]);
    }
    
    // 获取我的提现记录
    public function getMyList()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $list = Db::name('withdraw')
            ->where('user_id', $user->id)
            ->order('apply_time', 'desc')
            ->select();
        
        return json(['code' => 200, 'data' => $list]);
    }
    
    // 获取当前余额
    public function getBalance()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $currentHour = date('H');
        $canApply = false;
        if ($user->player_rank == 'gold') {
            $canApply = true;
        } else {
            $canApply = ($currentHour >= 8 && $currentHour < 20);
        }
        
        return json(['code' => 200, 'data' => [
            'balance' => $user->balance,
            'player_rank' => $user->player_rank,
            'can_withdraw' => $canApply,
            'current_hour' => $currentHour
        ]]);
    }
}