<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class User extends BaseController
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
    
    // 微信/QQ登录
    public function login()
    {
        $loginType = $this->request->post('login_type');
        $openid = $this->request->post('openid');
        $nickname = $this->request->post('nickname', '');
        
        if (!$loginType || !$openid) {
            return json(['code' => 400, 'msg' => '参数错误']);
        }
        
        $user = UserModel::where('openid', $openid)->find();
        
        if (!$user) {
            $user = UserModel::create([
                'openid' => $openid,
                'login_type' => $loginType,
                'nickname' => $nickname ?: '老板_' . rand(1000, 9999),
                'level' => 4,
                'player_rank' => 'bronze',
                'is_certified' => 0,
                'balance' => 0,
                'status' => 1
            ]);
        } else {
            if ($user->level == 5) {
                $user->level = 4;
                $user->nickname = $nickname ?: '老板_' . rand(1000, 9999);
                $user->save();
            }
        }
        
        $token = md5($user->id . time() . uniqid());
        Cache::set('token_' . $token, $user->id, 86400 * 7);
        
        $rankNames = ['gold' => '金牌', 'silver' => '银牌', 'bronze' => '铜牌'];
        
        return json([
            'code' => 200,
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'nickname' => $user->nickname,
                    'avatar' => $user->avatar,
                    'level' => $user->level,
                    'player_rank' => $user->player_rank,
                    'player_rank_name' => $rankNames[$user->player_rank],
                    'is_certified' => $user->is_certified,
                    'balance' => $user->balance,
                    'points' => $user->points
                ]
            ]
        ]);
    }
    
    // 游客登录
    public function guestLogin()
    {
        $guestId = 'guest_' . uniqid() . '_' . time();
        
        $user = UserModel::create([
            'openid' => $guestId,
            'login_type' => 'guest',
            'nickname' => '游客_' . rand(1000, 9999),
            'level' => 5,
            'player_rank' => 'bronze',
            'is_certified' => 0,
            'balance' => 0,
            'status' => 1
        ]);
        
        $token = md5($user->id . time() . uniqid());
        Cache::set('token_' . $token, $user->id, 86400);
        
        return json([
            'code' => 200,
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'nickname' => $user->nickname,
                    'level' => 5,
                    'need_login' => true
                ]
            ]
        ]);
    }
    
    // 修改昵称
    public function updateNickname()
    {
        $userId = $this->getUserId();
        $nickname = $this->request->post('nickname');
        
        if (!$nickname || mb_strlen($nickname) > 20) {
            return json(['code' => 400, 'msg' => '昵称长度1-20字符']);
        }
        
        $user = UserModel::find($userId);
        $user->nickname = $nickname;
        $user->save();
        
        return json(['code' => 200, 'msg' => '修改成功']);
    }
    
    // 获取用户信息
    public function getUserInfo()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '未登录']);
        }
        
        $rankNames = ['gold' => '金牌', 'silver' => '银牌', 'bronze' => '铜牌'];
        $levelNames = [1 => '管理员', 2 => '成员', 3 => '打手', 4 => '老板', 5 => '游客'];
        
        return json([
            'code' => 200,
            'data' => [
                'id' => $user->id,
                'nickname' => $user->nickname,
                'avatar' => $user->avatar,
                'level' => $user->level,
                'level_name' => $levelNames[$user->level],
                'player_rank' => $user->player_rank,
                'player_rank_name' => $rankNames[$user->player_rank],
                'is_certified' => $user->is_certified,
                'balance' => $user->balance,
                'points' => $user->points,
                'total_orders' => $user->total_orders,
                'total_earned' => $user->total_earned,
                'status' => $user->status
            ]
        ]);
    }
    
    // 管理员密码解锁
    public function unlockAdmin()
    {
        $userId = $this->getUserId();
        if (!$userId) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $password = $this->request->post('password');
        $secretPassword = '20100629tianxinyu';
        
        if ($password !== $secretPassword) {
            return json(['code' => 400, 'msg' => '密码错误']);
        }
        
        $user = UserModel::find($userId);
        if ($user->level == 1) {
            return json(['code' => 200, 'msg' => '您已经是管理员了']);
        }
        
        $user->level = 1;
        $user->is_certified = 1;
        $user->save();
        
        return json(['code' => 200, 'msg' => '解锁成功！您现在已成为管理员']);
    }
    
    // 检查是否为管理员
    public function checkAdmin()
    {
        $user = $this->getUser();
        $isAdmin = ($user && $user->level == 1);
        return json(['code' => 200, 'data' => ['is_admin' => $isAdmin]]);
    }
}