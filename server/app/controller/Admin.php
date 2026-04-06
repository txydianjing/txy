<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Admin extends BaseController
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
    
    private function checkAdmin()
    {
        $user = $this->getUser();
        return $user && $user->level == 1;
    }
    
    // 添加金牌打手
    public function addGoldPlayer()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $admin = $this->getUser();
        $userId = $this->request->post('user_id');
        $user = UserModel::find($userId);
        
        if (!$user || $user->level != 3) {
            return json(['code' => 400, 'msg' => '只能将打手升级为金牌']);
        }
        
        if ($user->player_rank != 'silver') {
            return json(['code' => 400, 'msg' => '金牌必须是银牌打手，请先升级为银牌']);
        }
        
        $oldRank = $user->player_rank;
        $user->player_rank = 'gold';
        $user->save();
        
        Db::name('player_rank_log')->insert([
            'user_id' => $userId,
            'old_rank' => $oldRank,
            'new_rank' => 'gold',
            'operator_id' => $admin->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '已升级为金牌打手']);
    }
    
    // 添加银牌打手
    public function addSilverPlayer()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $admin = $this->getUser();
        $userId = $this->request->post('user_id');
        $user = UserModel::find($userId);
        
        if (!$user || $user->level != 3) {
            return json(['code' => 400, 'msg' => '只能将打手升级为银牌']);
        }
        
        if ($user->player_rank != 'bronze') {
            return json(['code' => 400, 'msg' => '银牌必须是铜牌打手']);
        }
        
        $oldRank = $user->player_rank;
        $user->player_rank = 'silver';
        $user->save();
        
        Db::name('player_rank_log')->insert([
            'user_id' => $userId,
            'old_rank' => $oldRank,
            'new_rank' => 'silver',
            'operator_id' => $admin->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '已升级为银牌打手']);
    }
    
    // 获取所有打手列表
    public function getPlayerList()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $players = UserModel::where('level', 3)
            ->orderRaw("FIELD(player_rank, 'gold', 'silver', 'bronze')")
            ->field('id, nickname, player_rank, total_orders, total_earned, balance')
            ->select();
        
        return json(['code' => 200, 'data' => $players]);
    }
    
    // 获取所有用户列表
    public function getUserList()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $list = UserModel::field('id, nickname, avatar, level, player_rank, is_certified, balance, total_spent, total_earned, status, create_time')
            ->order('level', 'asc')
            ->select();
        
        $levelNames = [1 => '管理员', 2 => '成员', 3 => '打手', 4 => '老板', 5 => '游客'];
        $rankNames = ['gold' => '金牌', 'silver' => '银牌', 'bronze' => '铜牌'];
        foreach ($list as &$item) {
            $item['level_name'] = $levelNames[$item['level']];
            $item['player_rank_name'] = $rankNames[$item['player_rank']] ?? '铜牌';
        }
        
        return json(['code' => 200, 'data' => $list]);
    }
    
    // 任命成员
    public function appointMember()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $admin = $this->getUser();
        $targetId = $this->request->post('user_id');
        $target = UserModel::find($targetId);
        
        if (!$target) {
            return json(['code' => 400, 'msg' => '用户不存在']);
        }
        
        if (!in_array($target->level, [4,5])) {
            return json(['code' => 400, 'msg' => '该用户无法被任命为成员']);
        }
        
        $target->level = 2;
        $target->is_certified = 1;
        $target->save();
        
        Db::name('operate_log')->insert([
            'admin_id' => $admin->id,
            'action' => 'appoint_member',
            'target_id' => $targetId,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => "已将 {$target->nickname} 任命为成员"]);
    }
    
    // 任命打手
    public function appointPlayer()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $admin = $this->getUser();
        $targetId = $this->request->post('user_id');
        $target = UserModel::find($targetId);
        
        if (!$target) {
            return json(['code' => 400, 'msg' => '用户不存在']);
        }
        
        if ($target->level != 2) {
            return json(['code' => 400, 'msg' => '只能将成员任命为打手']);
        }
        
        $target->level = 3;
        $target->save();
        
        Db::name('operate_log')->insert([
            'admin_id' => $admin->id,
            'action' => 'appoint_player',
            'target_id' => $targetId,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => "已将 {$target->nickname} 任命为打手"]);
    }
    
    // 罚款
    public function fine()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $admin = $this->getUser();
        $targetId = $this->request->post('user_id');
        $amount = $this->request->post('amount');
        $reason = $this->request->post('reason', '');
        
        if ($amount <= 0 || $amount > 10) {
            return json(['code' => 400, 'msg' => '罚款金额必须在1-10元之间']);
        }
        
        $target = UserModel::find($targetId);
        if (!$target || $target->level != 2) {
            return json(['code' => 400, 'msg' => '只能对成员进行罚款']);
        }
        
        $target->balance -= $amount;
        $target->save();
        
        Db::name('punishment')->insert([
            'user_id' => $targetId,
            'admin_id' => $admin->id,
            'type' => 1,
            'amount' => $amount,
            'reason' => $reason,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => "已对用户 {$target->nickname} 罚款 {$amount} 元"]);
    }
    
    // 踢出用户
    public function kick()
    {
        if