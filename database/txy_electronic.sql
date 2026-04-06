-- =============================================
-- txy电竞 五级身份系统数据库
-- 暗区突围俱乐部
-- =============================================

DROP DATABASE IF EXISTS `txy_electronic`;
CREATE DATABASE `txy_electronic` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `txy_electronic`;

-- =============================================
-- 1. 用户表（五级身份系统）
-- =============================================
DROP TABLE IF EXISTS `txy_user`;
CREATE TABLE `txy_user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `openid` varchar(100) DEFAULT NULL COMMENT '微信/QQ唯一标识',
  `login_type` enum('wechat','qq','guest') DEFAULT 'guest' COMMENT '注册类型',
  `nickname` varchar(50) NOT NULL DEFAULT '游客' COMMENT '昵称',
  `avatar` varchar(500) DEFAULT NULL COMMENT '头像',
  `level` tinyint(1) NOT NULL DEFAULT 5 COMMENT '身份等级: 1管理员 2成员 3打手 4老板 5游客',
  `is_certified` tinyint(1) DEFAULT 0 COMMENT '是否经管理员认证标记(仅对成员有效)',
  `balance` decimal(10,2) DEFAULT 0.00 COMMENT '账户余额',
  `points` int(11) DEFAULT 0 COMMENT '积分',
  `total_spent` decimal(10,2) DEFAULT 0.00 COMMENT '累计消费',
  `total_earned` decimal(10,2) DEFAULT 0.00 COMMENT '累计收入(打手)',
  `status` tinyint(1) DEFAULT 1 COMMENT '状态: 1正常 0封禁',
  `ban_reason` varchar(200) DEFAULT NULL COMMENT '封禁原因',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_openid` (`openid`),
  KEY `idx_level` (`level`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表(五级身份)';

-- 插入默认管理员账号 (密码: admin123)
INSERT INTO `txy_user` (`openid`, `login_type`, `nickname`, `level`, `is_certified`) VALUES 
('admin_openid', 'wechat', '超级管理员', 1, 1);

-- =============================================
-- 2. 打手申请表（三级身份需管理员认证）
-- =============================================
DROP TABLE IF EXISTS `txy_player_apply`;
CREATE TABLE `txy_player_apply` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL COMMENT '申请人ID',
  `real_name` varchar(50) DEFAULT NULL COMMENT '真实姓名',
  `contact` varchar(100) DEFAULT NULL COMMENT '联系方式',
  `game_id` varchar(50) DEFAULT NULL COMMENT '游戏ID',
  `intro` varchar(500) DEFAULT NULL COMMENT '个人简介',
  `skill_tags` json DEFAULT NULL COMMENT '技能标签',
  `status` tinyint(1) NOT NULL DEFAULT 0 COMMENT '审核状态: 0待审核 1通过 2拒绝',
  `apply_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `review_time` datetime DEFAULT NULL,
  `reviewer_id` int(11) DEFAULT NULL COMMENT '审核人(管理员ID)',
  `review_remark` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='打手申请表';

-- =============================================
-- 3. 订单表（老板购买单子，打手接单）
-- =============================================
DROP TABLE IF EXISTS `txy_order`;
CREATE TABLE `txy_order` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_sn` varchar(32) NOT NULL COMMENT '订单号',
  `user_id` int(11) NOT NULL COMMENT '老板ID(4级)',
  `player_id` int(11) DEFAULT NULL COMMENT '接单打手ID(3级)',
  `service_type` tinyint(1) NOT NULL COMMENT '1:护航 2:代练 3:教学',
  `game_map` varchar(50) DEFAULT NULL COMMENT '游戏地图',
  `price` decimal(10,2) NOT NULL COMMENT '订单金额',
  `platform_fee` decimal(10,2) DEFAULT 0.00 COMMENT '平台抽成',
  `player_income` decimal(10,2) DEFAULT 0.00 COMMENT '打手收入',
  `status` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0待接单 1进行中 2已完成 3已取消 4退单中',
  `remark` varchar(500) DEFAULT NULL COMMENT '备注',
  `cancel_reason` varchar(200) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `complete_time` datetime DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_order_sn` (`order_sn`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_player_id` (`player_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

-- =============================================
-- 4. 退单/存单记录表（打手退单、存单）
-- =============================================
DROP TABLE IF EXISTS `txy_order_log`;
CREATE TABLE `txy_order_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `action` varchar(50) NOT NULL COMMENT '接单/退单/存单/完成',
  `user_id` int(11) NOT NULL,
  `reason` varchar(200) DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单操作日志';

-- =============================================
-- 5. 处罚记录表（管理员罚款成员，最多10元）
-- =============================================
DROP TABLE IF EXISTS `txy_punishment`;
CREATE TABLE `txy_punishment` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL COMMENT '被处罚用户ID',
  `admin_id` int(11) NOT NULL COMMENT '管理员ID',
  `type` tinyint(1) NOT NULL COMMENT '1:罚款 2:踢出 3:封禁',
  `amount` decimal(10,2) DEFAULT 0.00 COMMENT '罚款金额(最多10元)',
  `reason` varchar(200) NOT NULL COMMENT '处罚原因',
  `status` tinyint(1) DEFAULT 1,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='处罚记录表';

-- 触发器：限制罚款金额不超过10元
DELIMITER $$
CREATE TRIGGER `check_punishment_amount` BEFORE INSERT ON `txy_punishment`
FOR EACH ROW
BEGIN
  IF NEW.type = 1 AND NEW.amount > 10 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '罚款金额不能超过10元';
  END IF;
END$$
DELIMITER ;

-- =============================================
-- 6. 私信表（成员/管理员可私信，管理员无限制）
-- =============================================
DROP TABLE IF EXISTS `txy_message`;
CREATE TABLE `txy_message` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `from_user_id` int(11) NOT NULL,
  `to_user_id` int(11) NOT NULL,
  `content` varchar(1000) NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `read_time` datetime DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_from_to` (`from_user_id`, `to_user_id`),
  KEY `idx_to_user_id` (`to_user_id`, `is_read`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='私信表';

-- =============================================
-- 7. 提现申请表（打手专用，限时8:00-9:00）
-- =============================================
DROP TABLE IF EXISTS `txy_withdraw`;
CREATE TABLE `txy_withdraw` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL COMMENT '打手ID(3级)',
  `amount` decimal(10,2) NOT NULL COMMENT '申请金额',
  `image_url` varchar(500) NOT NULL COMMENT '上传的截图',
  `status` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0待处理 1已打款 2拒绝',
  `remark` varchar(200) DEFAULT NULL,
  `apply_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `process_time` datetime DEFAULT NULL,
  `processor_id` int(11) DEFAULT NULL COMMENT '处理人(管理员)',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='提现申请表';

-- =============================================
-- 8. 俱乐部表（只能加入，由管理员创建）
-- =============================================
DROP TABLE IF EXISTS `txy_club`;
CREATE TABLE `txy_club` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` <?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use app\model\Punishment;
use think\facade\Db;
use think\facade\Cache;

class User extends BaseController
{
    // 获取当前用户ID（从token解析）
    private function getUserId()
    {
        $token = $this->request->header('Authorization');
        $token = str_replace('Bearer ', '', $token);
        return Cache::get('token_' . $token);
    }
    
    // 获取当前用户完整信息
    private function getUser()
    {
        $userId = $this->getUserId();
        if (!$userId) return null;
        return UserModel::find($userId);
    }
    
    // 检查用户是否有指定权限（基于等级）
    private function checkLevel($requiredLevel)
    {
        $user = $this->getUser();
        if (!$user) return false;
        return $user->level <= $requiredLevel; // 等级数字越小权限越高
    }
    
    // 微信/QQ 登录（游客升级为老板）
    public function login()
    {
        $loginType = $this->request->post('login_type'); // wechat / qq
        $openid = $this->request->post('openid');
        $nickname = $this->request->post('nickname', '');
        
        if (!$loginType || !$openid) {
            return json(['code' => 400, 'msg' => '参数错误']);
        }
        
        $user = UserModel::where('openid', $openid)->find();
        
        if (!$user) {
            // 新注册用户：等级为4（老板）
            $user = UserModel::create([
                'openid' => $openid,
                'login_type' => $loginType,
                'nickname' => $nickname ?: '老板_' . rand(1000, 9999),
                'level' => 4,  // 老板
                'is_certified' => 0,
                'balance' => 0,
                'status' => 1
            ]);
        } else {
            // 老用户登录：如果是游客(5级)，升级为老板(4级)
            if ($user->level == 5) {
                $user->level = 4;
                $user->nickname = $nickname ?: '老板_' . rand(1000, 9999);
                $user->save();
            }
        }
        
        // 生成token
        $token = md5($user->id . time() . uniqid());
        Cache::set('token_' . $token, $user->id, 86400 * 7);
        
        return json([
            'code' => 200,
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'nickname' => $user->nickname,
                    'avatar' => $user->avatar,
                    'level' => $user->level,
                    'level_name' => $this->getLevelName($user->level),
                    'is_certified' => $user->is_certified,
                    'balance' => $user->balance,
                    'points' => $user->points
                ]
            ]
        ]);
    }
    
    // 游客模式（不登录直接进入，等级5）
    public function guestLogin()
    {
        $guestId = 'guest_' . uniqid() . '_' . time();
        
        $user = UserModel::create([
            'openid' => $guestId,
            'login_type' => 'guest',
            'nickname' => '游客_' . rand(1000, 9999),
            'level' => 5,  // 游客
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
                    'level_name' => '游客',
                    'need_login' => true
                ]
            ]
        ]);
    }
    
    // 修改昵称（所有用户都可修改）
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
    
    // 获取当前用户信息
    public function getUserInfo()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '未登录']);
        }
        
        return json([
            'code' => 200,
            'data' => [
                'id' => $user->id,
                'nickname' => $user->nickname,
                'avatar' => $user->avatar,
                'level' => $user->level,
                'level_name' => $this->getLevelName($user->level),
                'is_certified' => $user->is_certified,
                'balance' => $user->balance,
                'points' => $user->points,
                'total_spent' => $user->total_spent,
                'total_earned' => $user->total_earned,
                'status' => $user->status
            ]
        ]);
    }
    
    // 申请成为打手（3级，需管理员审核）
    public function applyPlayer()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 只有老板(4级)可以申请成为打手
        if ($user->level != 4) {
            return json(['code' => 400, 'msg' => '只有老板可以申请成为打手']);
        }
        
        // 检查是否已有申请
        $exist = Db::name('player_apply')->where('user_id', $user->id)->where('status', 0)->find();
        if ($exist) {
            return json(['code' => 400, 'msg' => '已有申请正在审核中']);
        }
        
        $data = $this->request->post(['real_name', 'contact', 'game_id', 'intro', 'skill_tags']);
        $data['user_id'] = $user->id;
        $data['apply_time'] = date('Y-m-d H:i:s');
        
        Db::name('player_apply')->insert($data);
        
        return json(['code' => 200, 'msg' => '申请已提交，请等待管理员审核']);
    }
    
    // 获取等级名称
    private function getLevelName($level)
    {
        $names = [
            1 => '管理员',
            2 => '成员',
            3 => '打手',
            4 => '老板',
            5 => '游客'
        ];
        return $names[$level] ?? '未知';
    }
    
    // 检查用户是否可以购买单子（1-4级都可以）
    public function canBuyOrder()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $canBuy = in_array($user->level, [1, 2, 3, 4]);
        return json(['code' => 200, 'data' => ['can_buy' => $canBuy]]);
    }
    
    // 获取所有用户列表（管理员专用）
    public function getUserList()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $list = UserModel::field('id, nickname, level, is_certified, balance, status, create_time')
            ->order('level', 'asc')
            ->select();
        
        foreach ($list as &$item) {
            $item['level_name'] = $this->getLevelName($item['level']);
        }
        
        return json(['code' => 200, 'data' => $list]);
    }
    
    // 踢出用户（封<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use app\model\Order as OrderModel;
use think\facade\Db;
use think\facade\Cache;

class Order extends BaseController
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
    
    // 检查是否可以购买单子（1-4级都可以）
    private function canBuy($user)
    {
        return in_array($user->level, [1, 2, 3, 4]);
    }
    
    // 生成订单号
    private function generateOrderSn()
    {
        return date('YmdHis') . rand(10000, 99999);
    }
    
    // ========== 老板：发布订单（购买单子） ==========
    public function create()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 检查是否可以购买单子
        if (!$this->canBuy($user)) {
            return json(['code' => 403, 'msg' => '游客无法购买单子，请登录后重试']);
        }
        
        $data = $this->request->post(['service_type', 'game_map', 'price', 'remark']);
        
        if (empty($data['service_type']) || empty($data['price']) || $data['price'] <= 0) {
            return json(['code' => 400, 'msg' => '参数错误']);
        }
        
        $order = OrderModel::create([
            'order_sn' => $this->generateOrderSn(),
            'user_id' => $user->id,
            'service_type' => $data['service_type'],
            'game_map' => $data['game_map'] ?? '',
            'price' => $data['price'],
            'platform_fee' => round($data['price'] * 0.1, 2),
            'player_income' => round($data['price'] * 0.9, 2),
            'status' => 0,
            'remark' => $data['remark'] ?? '',
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        // 扣减老板余额
        $user->balance -= $data['price'];
        $user->total_spent += $data['price'];
        $user->save();
        
        // 记录日志
        Db::name('order_log')->insert([
            'order_id' => $order->id,
            'action' => '创建订单',
            'user_id' => $user->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'data' => $order, 'msg' => '下单成功']);
    }
    
    // ========== 打手：获取可接单列表 ==========
    public function getAvailableOrders()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 只有打手(3级)和管理员(1级)可以查看接单列表
        if (!in_array($user->level, [1, 3])) {
            return json(['code' => 403, 'msg' => '只有打手可以接单']);
        }
        
        $orders = OrderModel::where('status', 0)
            ->order('create_time', 'asc')
            ->select();
        
        return json(['code' => 200, 'data' => $orders]);
    }
    
    // ========== 打手：接单 ==========
    public function grab()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 只有打手(3级)和管理员(1级)可以接单
        if (!in_array($user->level, [1, 3])) {
            return json(['code' => 403, 'msg' => '您不是打手，无法接单']);
        }
        
        $orderId = $this->request->post('order_id');
        
        // 使用锁防止并发抢单
        $order = OrderModel::where('id', $orderId)->lock(true)->find();
        
        if (!$order) {
            return json(['code' => 400, 'msg' => '订单不存在']);
        }
        
        if ($order->status != 0) {
            return json(['code' => 400, 'msg' => '订单已被抢走']);
        }
        
        $order->player_id = $user->id;
        $order->status = 1;
        $order->start_time = date('Y-m-d H:i:s');
        $order->save();
        
        // 记录日志
        Db::name('order_log')->insert([
            'order_id' => $orderId,
            'action' => '接单',
            'user_id' => $user->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '接单成功']);
    }
    
    // ========== 打手：退单 ==========
    public function cancelOrder()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 只有打手(3级)和管理员(1级)可以退单
        if (!in_array($user->level, [1, 3])) {
            return json(['code' => 403, 'msg' => '无权限退单']);
        }
        
        $orderId = $this->request->post('order_id');
        $reason = $this->request->post('reason', '');
        
        $order = OrderModel::where('id', $orderId)->where('player_id', $user->id)->find();
        
        if (!$order) {
            return json(['code' => 400, 'msg' => '订单不存在或不是你接的单']);
        }
        
        if ($order->status != 1) {
            return json(['code' => 400, 'msg' => '当前订单状态无法退单']);
        }
        
        $order->status = 3;  // 已取消
        $order->cancel_reason = $reason;
        $order->save();
        
        // 退还老板余额
        $boss = UserModel::find($order->user_id);
        $boss->balance += $order->price;
        $boss->save();
        
        // 记录日志
        Db::name('order_log')->insert([
            'order_id' => $orderId,
            'action' => '退单',
            'user_id' => $user->id,
            'reason' => $reason,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '退单成功，金额已退还']);
    }
    
    // ========== 打手：存单（暂停/暂存订单） ==========
    public function saveOrder()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        if (!in_array($user->level, [1, 3])) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $orderId = $this->request->post('order_id');
        
        $order = OrderModel::where('id', $orderId)->where('player_id', $user->id)->find();
        
        if (!$order) {
            return json(['code' => 400, 'msg' => '订单不存在']);
        }
        
        if ($order->status != 1) {
            return json(['code' => 400, 'msg' => '当前订单状态无法存单']);
        }
        
        $order->status = 4;  // 存单中
        $order->save();
        
        Db::name('order_log')->insert([
            'order_id' => $orderId,
            'action' => '存单',
            'user_id' => $user->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '已暂存订单，可在我的订单中继续']);
    }
    
    // ========== 打手：完成订单 ==========
    public function completeOrder()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        if (!in_array($user->level, [1, 3])) {
            return json(['code' => 403, 'msg' => '无权限']);
        <?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Message extends BaseController
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
    
    // 发送私信
    public function send()
    {
        $fromUser = $this->getUser();
        if (!$fromUser) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $toUserId = $this->request->post('to_user_id');
        $content = $this->request->post('content');
        
        if (empty($content) || mb_strlen($content) > 1000) {
            return json(['code' => 400, 'msg' => '内容不能为空且不能超过1000字']);
        }
        
        $toUser = UserModel::find($toUserId);
        if (!$toUser) {
            return json(['code' => 400, 'msg' => '接收方不存在']);
        }
        
        // 权限检查：
        // 1. 管理员(1级)可以给任何人发私信，无限制
        // 2. 成员(2级)可以发私信（但会被记录，管理员可罚款）
        // 3. 其他等级不能发私信
        
        if ($fromUser->level == 1) {
            // 管理员无限制
        } elseif ($fromUser->level == 2) {
            // 成员可以发私信，记录用于监控
            Db::name('message_log')->insert([
                'user_id' => $fromUser->id,
                'action' => 'send_message',
                'content' => $content,
                'to_user_id' => $toUserId,
                'create_time' => date('Y-m-d H:i:s')
            ]);
        } else {
            return json(['code' => 403, 'msg' => '只有管理员和成员可以发送私信']);
        }
        
        Db::name('message')->insert([
            'from_user_id' => $fromUser->id,
            'to_user_id' => $toUserId,
            'content' => $content,
            'is_read' => 0,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '发送成功']);
    }
    
    // 获取私信列表
    public function getList()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $messages = Db::name('message')
            ->where('to_user_id', $user->id)
            ->order('create_time', 'desc')
            ->select();
        
        // 获取发送者信息
        foreach ($messages as &$msg) {
            $fromUser = UserModel::find($msg['from_user_id']);
            $msg['from_nickname'] = $fromUser ? $fromUser->nickname : '未知';
            $msg['from_level'] = $fromUser ? $fromUser->level : 0;
        }
        
        return json(['code' => 200, 'data' => $messages]);
    }
    
    // 标记已读
    public function markRead()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $messageId = $this->request->post('message_id');
        
        Db::name('message')->where('id', $messageId)->where('to_user_id', $user->id)->update([
            'is_read' => 1,
            'read_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '已标记已读']);
    }
}<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Punishment extends BaseController
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
    
    // 罚款用户（管理员专用，只能罚成员，最多10元）
    public function fine()
    {
        $admin = $this->getUser();
        if (!$admin || $admin->level != 1) {
            return json(['code' => 403, 'msg' => '只有管理员可以执行罚款']);
        }
        
        $targetId = $this->request->post('user_id');
        $amount = $this->request->post('amount');
        $reason = $this->request->post('reason', '');
        
        // 金额验证：不能超过10元
        if ($amount <= 0 || $amount > 10) {
            return json(['code' => 400, 'msg' => '罚款金额必须在1-10元之间']);
        }
        
        $target = UserModel::find($targetId);
        if (!$target) {
            return json(['code' => 400, 'msg' => '用户不存在']);
        }
        
        // 只能罚成员(2级)
        if ($target->level != 2) {
            return json(['code' => 400, 'msg' => '只能对成员进行罚款']);
        }
        
        // 扣款
        $target->balance -= $amount;
        $target->save();
        
        // 记录处罚
        Db::name('punishment')->insert([
            'user_id' => $targetId,
            'admin_id' => $admin->id,
            'type' => 1,
            'amount' => $amount,
            'reason' => $reason,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        // 记录操作日志
        Db::name('operate_log')->insert([
            'admin_id' => $admin->id,
            'action' => 'fine',
            'target_id' => $targetId,
            'details' => json_encode(['amount' => $amount, 'reason' => $reason]),
            'ip' => $this->request->ip(),
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => "已对用户 {$target->nickname} 罚款 {$amount} 元"]);
    }
    
    // 获取处罚记录（管理员专用）
    public function getPunishmentList()
    {
        $admin = $this->getUser();
        if (!$admin || $admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $list = Db::name('punishment')->alias('p')
            ->join('txy_user u', 'p.user_id = u.id')
            ->join('txy_user a', 'p.admin_id = a.id')
            ->field('p.*, u.nickname as user_nickname, a.nickname as admin_nickname')
            ->order('p.create_time', 'desc')
            ->select();
        
        return json(['code' => 200, 'data' => $list]);
    }
}<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;
use think\facade\Config;

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
    
    // 检查是否在提现时间内
    private function checkWithdrawTime()
    {
        $now = date('H:i');
        $startTime = '08:00';
        $endTime = '09:00';
        
        // 从配置读取（可选）
        $startTime = Db::name('config')->where('key', 'withdraw_start_time')->value('value') ?: '08:00';
        $endTime = Db::name('config')->where('key', 'withdraw_end_time')->value('value') ?: '09:00';
        
        return ($now >= $startTime && $now <= $endTime);
    }
    
    // 申请提现（打手专用，限时，必须上传截图）
    public function apply()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 只有打手(3级)可以提现
        if ($user->level != 3) {
            return json(['code' => 403, 'msg' => '只有打手可以提现']);
        }
        
        // 检查提现时间
        if (!$this->checkWithdrawTime()) {
            return json(['code' => 400, 'msg' => '提现时间仅限每天 8:00 - 9:00，请在此时间段内申请']);
        }
        
        $amount = $this->request->post('amount');
        $image = $this->request->file('image');
        
        if (!$amount || $amount <= 0) {
            return json(['code' => 400, 'msg' => '请输入正确的金额']);
        }
        
        if ($amount > $user->balance) {
            return json(['code' => 400, 'msg' => '余额不足']);
        }
        
        if (!$image) {
            return json(['code' => 400, 'msg' => '请上传截图凭证']);
        }
        
        // 检查文件类型
        $allowedTypes = ['image/jpeg', 'image/png', 'image/jpg'];
        if (!in_array($image->getMime(), $allowedTypes)) {
            return json(['code' => 400, 'msg' => '只支持 JPG/PNG 格式图片']);
        }
        
        // 保存图片
        $savePath = 'uploads/withdraw/' . date('Ymd') . '/';
        $imageName = $user->id . '_' . time() . '_' . rand(1000, 9999) . '.' . $image->extension();
        $image->move($savePath, $imageName);
        
        // 创建提现申请
        Db::name('withdraw')->insert([
            'user_id' => $user->id,
            'amount' => $amount,
            'image_url' => $savePath . $imageName,
            'status' => 0,
            'apply_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '提现申请已提交，请等待管理员处理']);
    }
    
    // 获取提现记录（打手查看自己的）
    public function getMyWithdrawList()
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
        
        return json([
            'code' => 200,
            'data' => [
                'balance' => $user->balance,
                'level' => $user->level,
                'level_name' => $this->getLevelName($user->level),
                'withdraw_time_valid' => $this->checkWithdrawTime()
            ]
        ]);
    }
    
    private function getLevelName($level)
    {
        $names = [1 => '管理员', 2 => '成员', 3 => '打手', 4 => '老板', 5 => '游客'];
        return $names[$level] ?? '未知';
    }
}<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Club extends BaseController
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
    
    // 获取俱乐部列表（管理员创建的，用户只能加入）
    public function getClubList()
    {
        $clubs = Db::name('club')
            ->order('member_count', 'desc')
            ->select();
        
        return json(['code' => 200, 'data' => $clubs]);
    }
    
    // 获取俱乐部详情
    public function getClubDetail()
    {
        $clubId = $this->request->get('club_id');
        
        $club = Db::name('club')->find($clubId);
        if (!$club) {
            return json(['code' => 400, 'msg' => '俱乐部不存在']);
        }
        
        // 获取成员列表
        $members = Db::name('club_member')->alias('cm')
            ->join('txy_user u', 'cm.user_id = u.id')
            ->field('u.id, u.nickname, u.avatar, u.level, cm.join_time')
            ->where('cm.club_id', $clubId)
            ->select();
        
        $club['members'] = $members;
        
        return json(['code' => 200, 'data' => $club]);
    }
    
    // 加入俱乐部
    public function join()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $clubId = $this->request->post('club_id');
        
        $club = Db::name('club')->find($clubId);
        if (!$club) {
            return json(['code' => 400, 'msg' => '俱乐部不存在']);
        }
        
        // 检查是否已加入
        $exist = Db::name('club_member')->where('club_id', $clubId)->where('user_id', $user->id)->find();
        if ($exist) {
            return json(['code' => 400, 'msg' => '您已加入该俱乐部']);
        }
        
        // 加入
        Db::name('club_member')->insert([
            'club_id' => $clubId,
            'user_id' => $user->id,
            'join_time' => date('Y-m-d H:i:s')
        ]);
        
        // 更新俱乐部成员数
        Db::name('club')->where('id', $clubId)->inc('member_count')->update();
        
        return json(['code' => 200, 'msg' => '加入成功']);
    }
    
    // 退出俱乐部
    public function quit()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $clubId = $this->request->post('club_id');
        
        $member = Db::name('club_member')->where('club_id', $clubId)->where('user_id', $user->id)->find();
        if (!$member) {
            return json(['code' => 400, 'msg' => '您未加入该俱乐部']);
        }
        
        Db::name('club_member')->where('id', $member['id'])->delete();
        Db::name('club')->where('id', $clubId)->dec('member_count')->update();
        
        return json(['code' => 200, 'msg' => '退出成功']);
    }
    
    // 获取我的俱乐部
    public function getMyClub()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $member = Db::name('club_member')->where('user_id', $user->id)->find();
        if (!$member) {
            return json(['code' => 200, 'data' => null, 'msg' => '未加入任何俱乐部']);
        }
        
        $club = Db::name('club')->find($member['club_id']);
        
        return json(['code' => 200, 'data' => $club]);
    }
}<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Cache;

class AdminSecret extends BaseController
{
    private $secretPassword = '20100629tianxinyu';
    
    private function getUserId()
    {
        $token = $this->request->header('Authorization');
        $token = str_replace('Bearer ', '', $token);
        return Cache::get('token_' . $token);
    }
    
    // 验证密码并升级为管理员
    public function unlockAdmin()
    {
        $userId = $this->getUserId();
        if (!$userId) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $password = $this->request->post('password');
        
        if ($password !== $this->secretPassword) {
            return json(['code' => 400, 'msg' => '密码错误']);
        }
        
        $user = UserModel::find($userId);
        if (!$user) {
            return json(['code' => 400, 'msg' => '用户不存在']);
        }
        
        // 已经是管理员
        if ($user->level == 1) {
            return json(['code' => 200, 'msg' => '您已经是管理员了']);
        }
        
        // 升级为管理员
        $oldLevel = $user->level;
        $user->level = 1;
        $user->is_certified = 1;
        $user->save();
        
        // 记录操作日志
        \think\facade\Db::name('operate_log')->insert([
            'admin_id' => $userId,
            'action' => 'unlock_admin',
            'details' => json_encode(['old_level' => $oldLevel, 'method' => 'secret_password']),
            'ip' => $this->request->ip(),
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json([
            'code' => 200, 
            'msg' => '解锁成功！您现在已成为管理员，拥有所有权限',
            'data' => ['level' => 1, 'level_name' => '管理员']
        ]);
    }
    
    // 检查当前用户是否为管理员
    public function checkAdmin()
    {
        $userId = $this->getUserId();
        if (!$userId) {
            return json(['code' => 200, 'data' => ['is_admin' => false]]);
        }
        
        $user = UserModel::find($userId);
        $isAdmin = ($user && $user->level == 1);
        
        return json(['code' => 200, 'data' => ['is_admin' => $isAdmin]]);
    }
}<?php
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
    
    // 检查是否为管理员
    private function checkAdmin()
    {
        $user = $this->getUser();
        if (!$user || $user->level != 1) {
            return false;
        }
        return true;
    }
    
    // ========== 任命成员（将老板/游客升级为成员，2级） ==========
    public function appointMember()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限，只有管理员可以操作']);
        }
        
        $admin = $this->getUser();
        $targetId = $this->request->post('user_id');
        
        $target = UserModel::find($targetId);
        if (!$target) {
            return json(['code' => 400, 'msg' => '用户不存在']);
        }
        
        // 只能任命老板(4级)或游客(5级)为成员
        if (!in_array($target->level, [4, 5])) {
            return json(['code' => 400, 'msg' => '该用户无法被任命为成员（只能是老板或游客）']);
        }
        
        $oldLevel = $target->level;
        $target->level = 2;
        $target->is_certified = 1;
        $target->save();
        
        // 记录日志
        Db::name('operate_log')->insert([
            'admin_id' => $admin->id,
            'action' => 'appoint_member',
            'target_id' => $targetId,
            'details' => json_encode(['old_level' => $oldLevel, 'new_level' => 2]),
            'ip' => $this->request->ip(),
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => "已将 {$target->nickname} 任命为成员"]);
    }
    
    // ========== 任命打手（将成员升级为打手，3级） ==========
    public function appointPlayer()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限，只有管理员可以操作']);
        }
        
        $admin = $this->getUser();
        $targetId = $this->request->post('user_id');
        
        $target = UserModel::find($targetId);
        if (!$target) {
            return json(['code' => 400, 'msg' => '用户不存在']);
        }
        
        // 只能任命成员(2级)为打手
        if ($target->level != 2) {
            return json(['code' => 400, 'msg' => '只能将成员任命为打手']);
        }
        
        $oldLevel = $target->level;
        $target->level = 3;
        $target->save();
        
        // 记录日志
        Db::name('operate_log')->insert([
            'admin_id' => $admin->id,
            'action' => 'appoint_player',
            'target_id' => $targetId,
            'details' => json_encode(['old_level' => $oldLevel, 'new_level' => 3]),
            'ip' => $this->request->ip(),
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => "已将 {$target->nickname} 任命为打手"]);
    }
    
    // ========== 获取所有用户列表（供后台管理） ==========
    public function getUserList()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $list = UserModel::field('id, nickname, avatar, level, is_certified, balance, total_spent, total_earned, status, create_time')
            ->order('level', 'asc')
            ->select();
        
        $levelNames = [1 => '管理员', 2 => '成员', 3 => '打手', 4 => '老板', 5 => '游客'];
        foreach ($list as &$item) {
            $item['level_name'] = $levelNames[$item['level']];
        }
        
        return json(['code' => 200, 'data' => $list]);
    }
    
    // ========== 获取流水数据（订单流水、提现流水） ==========
    public function getFinancialData()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        // 订单流水
        $orders = Db::name('order')
            ->field('id, order_sn, price, platform_fee, player_income, status, create_time, complete_time')
            ->order('create_time', 'desc')
            ->limit(100)
            ->select();
        
        // 提现流水
        $withdraws = Db::name('withdraw')->alias('w')
            ->join('txy_user u', 'w.user_id = u.id')
            ->field('w.*, u.nickname')
            ->order('w.apply_time', 'desc')
            ->limit(100)
            ->select();
        
        // 处罚流水（罚款）
        $punishments = Db::name('punishment')->alias('p')
            ->join('txy_user u', 'p.user_id = u.id')
            ->field('p.*, u.nickname')
            ->order('p.create_time', 'desc')
            ->limit(100)
            ->select();
        
        // 统计数据
        $statistics = [
            'total_order_amount' => Db::name('order')->where('status', 2)->sum('price') ?: 0,
            'total_platform_fee' => Db::name('order')->where('status', 2)->sum('platform_fee') ?: 0,
            'total_withdraw_amount' => Db::name('withdraw')->where('status', 1)->sum('amount') ?: 0,
            'total_fine_amount' => Db::name('punishment')->where('type', 1)->sum('amount') ?: 0,
            'total_users' => Db::name('user')->count(),
            'total_orders' => Db::name('order')->count(),
            'completed_orders' => Db::name('order')->where('status', 2)->count(),
        ];
        
        return json([
            'code' => 200,
            'data' => [
                'statistics' => $statistics,
                'orders' => $orders,
                'withdraws' => $withdraws,
                'punishments' => $punishments
            ]
        ]);
    }
    
    // ========== 获取待处理提现申请 ==========
    public function getPendingWithdraws()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $list = Db::name('withdraw')->alias('w')
            ->join('txy_user u', 'w.user_id = u.id')
            ->field('w.*, u.nickname, u.balance')
            ->where('w.status', 0)
            ->order('w.apply_time', 'asc')
            ->select();
        
        return json(['code' => 200, 'data' => $list]);
    }
    
    // ========== 处理提现（打款） ==========
    public function processWithdraw()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $admin = $this->getUser();
        $withdrawId = $this->request->post('withdraw_id');
        $action = $this->request->post('action'); // approve / reject
        $remark = $this->request->post('remark', '');
        
        $withdraw = Db::name('withdraw')->find($withdrawId);
        if (!$withdraw || $withdraw['status'] != 0) {
            return json(['code' => 400, 'msg' => '提现申请不存在或已处理']);
        }
        
        if ($action == 'approve') {
            // 批准：扣减用户余额
            $user = UserModel::find($withdraw['user_id']);
           <template>
  <view class="page">
    <!-- 用户信息卡片 -->
    <view class="user-card">
      <image class="avatar" :src="userInfo.avatar || '/static/default-avatar.png'" mode="aspectFill"></image>
      <view class="info">
        <view class="nickname-row">
          <text class="nickname">{{ userInfo.nickname || '未登录' }}</text>
          <view class="level-tag" :class="'level-' + userInfo.level">
            {{ levelName }}
          </view>
        </view>
        <text class="user-id">ID: {{ userInfo.id || '未登录' }}</text>
        <view class="balance-row">
          <text class="balance">余额: ¥{{ userInfo.balance || 0 }}</text>
          <text class="points">积分: {{ userInfo.points || 0 }}</text>
        </view>
      </view>
    </view>
    
    <!-- 管理员解锁按钮（隐藏，需要多次点击） -->
    <view class="secret-area" @click="onSecretClick">
      <text v-if="!isAdmin" class="secret-hint">*</text>
    </view>
    
    <!-- 管理员解锁弹窗 -->
    <uni-popup ref="adminPopup" type="center">
      <view class="admin-popup">
        <text class="popup-title">管理员解锁</text>
        <input 
          class="popup-input" 
          type="password" 
          v-model="adminPassword" 
          placeholder="请输入管理员密码"
          :password="true"
        />
        <view class="popup-buttons">
          <button class="popup-btn cancel" @click="closeAdminPopup">取消</button>
          <button class="popup-btn confirm" @click="unlockAdmin">确认</button>
        </view>
      </view>
    </uni-popup>
    
    <!-- 如果是管理员，显示后台管理入口 -->
    <view class="section" v-if="isAdmin">
      <view class="section-title">管理后台</view>
      <view class="menu-grid">
        <view class="menu-item" @click="goTo('/pages/admin/users')">
          <text>👥</text>
          <text>用户管理</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/admin/finance')">
          <text>💰</text>
          <text>财务流水</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/admin/withdraw')">
          <text>🏦</text>
          <text>提现处理</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/admin/punish')">
          <text>⚖️</text>
          <text>处罚管理</text>
        </view>
      </view>
    </view>
    
    <!-- 普通功能菜单 -->
    <view class="section">
      <view class="section-title">我的订单</view>
      <view class="menu-list">
        <view class="menu-item" @click="goTo('/pages/order/list')">
          <text>📋</text>
          <text>我的订单</text>
          <text class="arrow">›</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/order/create')" v-if="canBuy">
          <text>📝</text>
          <text>发布订单</text>
          <text class="arrow">›</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/player/grab')" v-if="isPlayer">
          <text>⚡</text>
          <text>抢单大厅</text>
          <text class="arrow">›</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/player/orders')" v-if="isPlayer">
          <text>📦</text>
          <text>我接的订单</text>
          <text class="arrow">›</text>
        </view>
      </view>
    </view>
    
    <!-- 资金相关 -->
    <view class="section">
      <view class="section-title">资金管理</view>
      <view class="menu-list">
        <view class="menu-item" @click="goTo('/pages/withdraw/index')" v-if="isPlayer">
          <text>💸</text>
          <text>提现申请</text>
          <text class="arrow">›</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/withdraw/record')" v-if="isPlayer">
          <text>📊</text>
          <text>提现记录</text>
          <text class="arrow">›</text>
        </view>
      </view>
    </view>
    
    <!-- 俱乐部 -->
    <view class="section">
      <view class="section-title">俱乐部</view>
      <view class="menu-list">
        <view class="menu-item" @click="goTo('/pages/club/list')">
          <text>🏛️</text>
          <text>俱乐部列表</text>
          <text class="arrow">›</text>
        </view>
        <view class="menu-item" @click="goTo('/pages/club/my')">
          <text>👥</text>
          <text>我的俱乐部</text>
          <text class="arrow">›</text>
        </view>
      </view>
    </view>
    
    <!-- 设置 -->
    <view class="section">
      <view class="section-title">设置</view>
      <view class="menu-list">
        <view class="menu-item" @click="showNicknameDialog">
          <text>✏️</text>
          <text>修改昵称</text>
          <text class="arrow">›</text>
        </view>
        <view class="menu-item" @click="logout" v-if="isLoggedIn">
          <text>🚪</text>
          <text>退出登录</text>
          <text class="arrow">›</text>
        </view>
      </view>
    </view>
    
    <!-- 修改昵称弹窗 -->
    <uni-popup ref="nicknamePopup" type="center">
      <view class="admin-popup">
        <text class="popup-title">修改昵称</text>
        <input class="popup-input" v-model="newNickname" placeholder="请输入新昵称" maxlength="20" />
        <view class="popup-buttons">
          <button class="popup-btn cancel" @click="closeNicknamePopup">取消</button>
          <button class="popup-btn confirm" @click="updateNickname">确认</button>
        </view>
      </view>
    </uni-popup>
  </view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { onShow } from '@dcloudio/uni-app';
import { useUserStore } from '@/store/user';
import { updateNicknameApi, unlockAdminApi, checkAdminApi } from '@/api/user';

const userStore = useUserStore();
const userInfo = ref({});
const isAdmin = ref(false);
const adminPassword = ref('');
const newNickname = ref('');
const clickCount = ref(0);
let clickTimer = null;

const levelName = computed(() => {
  const names = { 1: '管理员', 2: '成员', 3: '打手', 4: '老板', 5: '游客' };
  return names[userInfo.value.level] || '未知';
});

const isLoggedIn = computed(() => userInfo.value.id && userInfo.value.level !== 5);
const canBuy = computed(() => [1, 2, 3, 4].includes(userInfo.value.level));
const isPlayer = computed(() => [1, 3].includes(userInfo.value.level));

// 加载用户信息
const loadUserInfo = async () => {
  const token = uni.getStorageSync('token');
  if (!token) {
    userInfo.value = { level: 5, nickname: '游客' };
    isAdmin.value = false;
    return;
  }
  
  try {
    const res = await userStore.getUserInfo();
    if (res && res.code === 200) {
      userInfo.value = res.data;
      isAdmin.value = userInfo.value.level === 1;
    }
  } catch (e) {
    console.error(e);
  }
};

// 管理员解锁按钮：连续点击5次
const onSecretClick = () => {
  if (isAdmin.value) return;
  
  clickCount.value++;
  if (clickTimer) clearTimeout(clickTimer);
  clickTimer = setTimeout(() => {
    clickCount.value = 0;
  }, 2000);
  
  if (clickCount.value >= 5) {
    clickCount.value = 0;
    adminPassword.value = '';
    uni.$refs.adminPopup.open();
  }
};

const closeAdminPopup = () => {
  uni.$refs.adminPopup.close();
};

const unlockAdmin = async () => {
  if (!adminPassword.value) {
    uni.showToast({ title: '请输入密码', icon: 'none' });
    return;
  }
  
 <template>
  <view class="page">
    <view class="header">
      <text class="title">用户管理</text>
      <text class="subtitle">管理员权限 · 可任命成员/打手</text>
    </view>
    
    <!-- 统计卡片 -->
    <view class="stats-grid">
      <view class="stat-card">
        <text class="stat-num">{{ stats.total }}</text>
        <text class="stat-label">总用户数</text>
      </view>
      <view class="stat-card">
        <text class="stat-num">{{ stats.admin }}</text>
        <text class="stat-label">管理员</text>
      </view>
      <view class="stat-card">
        <text class="stat-num">{{ stats.member }}</text>
        <text class="stat-label">成员</text>
      </view>
      <view class="stat-card">
        <text class="stat-num">{{ stats.player }}</text>
        <text class="stat-label">打手</text>
      </view>
    </view>
    
    <!-- 筛选栏 -->
    <view class="filter-bar">
      <view class="filter-item" :class="{ active: filterLevel === '' }" @click="filterLevel = ''">全部</view>
      <view class="filter-item" :class="{ active: filterLevel === 1 }" @click="filterLevel = 1">管理员</view>
      <view class="filter-item" :class="{ active: filterLevel === 2 }" @click="filterLevel = 2">成员</view>
      <view class="filter-item" :class="{ active: filterLevel === 3 }" @click="filterLevel = 3">打手</view>
      <view class="filter-item" :class="{ active: filterLevel === 4 }" @click="filterLevel = 4">老板</view>
      <view class="filter-item" :class="{ active: filterLevel === 5 }" @click="filterLevel = 5">游客</view>
    </view>
    
    <!-- 用户列表 -->
    <view class="user-list">
      <view class="user-card" v-for="user in filteredUsers" :key="user.id">
        <image class="avatar" :src="user.avatar || '/static/default-avatar.png'" mode="aspectFill"></image>
        <view class="info">
          <view class="name-row">
            <text class="nickname">{{ user.nickname }}</text>
            <view class="level-tag" :class="'level-' + user.level">
              {{ getLevelName(user.level) }}
            </view>
            <view class="status-tag" v-if="user.status === 0" class="banned">已封禁</view>
          </view>
          <text class="user-id">ID: {{ user.id }}</text>
          <view class="balance-row">
            <text>余额: ¥{{ user.balance }}</text>
            <text class="spent">消费: ¥{{ user.total_spent }}</text>
          </view>
        </view>
        <view class="actions">
          <!-- 任命为成员（仅对老板/游客显示） -->
          <button 
            v-if="user.level === 4 || user.level === 5" 
            class="action-btn member"
            @click="appointMember(user)"
          >
            任命成员
          </button>
          <!-- 任命为打手（仅对成员显示） -->
          <button 
            v-if="user.level === 2" 
            class="action-btn player"
            @click="appointPlayer(user)"
          >
            任命打手
          </button>
          <!-- 罚款（仅对成员显示） -->
          <button 
            v-if="user.level === 2" 
            class="action-btn fine"
            @click="showFineDialog(user)"
          >
            罚款
          </button>
          <!-- 踢出/封禁 -->
          <button 
            v-if="user.level !== 1 && user.status === 1" 
            class="action-btn kick"
            @click="kickUser(user)"
          >
            踢出
          </button>
          <!-- 解封 -->
          <button 
            v-if="user.status === 0" 
            class="action-btn unban"
            @click="unbanUser(user)"
          >
            解封
          </button>
        </view>
      </view>
    </view>
    
    <!-- 空状态 -->
    <view class="empty" v-if="filteredUsers.length === 0">
      <text>暂无用户数据</text>
    </view>
    
    <!-- 罚款弹窗 -->
    <uni-popup ref="finePopup" type="center">
      <view class="popup-container">
        <text class="popup-title">罚款用户</text>
        <text class="popup-user">用户：{{ fineTarget.nickname }}</text>
        <input 
          class="popup-input" 
          type="number" 
          v-model="fineAmount" 
          placeholder="罚款金额 (1-10元)"
        />
        <input 
          class="popup-input" 
          v-model="fineReason" 
          placeholder="罚款原因"
        />
        <view class="popup-buttons">
          <button class="popup-btn cancel" @click="closeFineDialog">取消</button>
          <button class="popup-btn confirm" @click="submitFine">确认罚款</button>
        </view>
      </view>
    </uni-popup>
  </view>
</template>

<script setup>
import { ref, computed, onShow } from 'vue';
import { getUserList, appointMemberApi, appointPlayerApi, fineUserApi, kickUserApi, unbanUserApi } from '@/api/admin';

const users = ref([]);
const filterLevel = ref('');
const fineTarget = ref({});
const fineAmount = ref('');
const fineReason = ref('');
const stats = ref({ total: 0, admin: 0, member: 0, player: 0 });

const filteredUsers = computed(() => {
  if (filterLevel.value === '') return users.value;
  return users.value.filter(u => u.level === filterLevel.value);
});

const getLevelName = (level) => {
  const names = { 1: '管理员', 2: '成员', 3: '打手', 4: '老板', 5: '游客' };
  return names[level] || '未知';
};

const loadUsers = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getUserList();
    if (res.code === 200) {
      users.value = res.data;
      // 统计
      stats.value = {
        total: users.value.length,
        admin: users.value.filter(u => u.level === 1).length,
        member: users.value.filter(u => u.level === 2).length,
        player: users.value.filter(u => u.level === 3).length
      };
    }
  } catch (e) {
    uni.showToast({ title: '加载失败', icon: 'error' });
  }
  uni.hideLoading();
};

const appointMember = async (user) => {
  uni.showModal({
    title: '确认任命',
    content: `确定要将 ${user.nickname} 任命为成员吗？`,
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '处理中...' });
        try {
          const result = await appointMemberApi(user.id);
          if (result.code === 200) {
            uni.showToast({ title: result.msg, icon: 'success' });
            loadUsers();
          } else {
            uni.showToast({ title: result.msg, icon: 'error' });
          }
        } catch (e) {
          uni.showToast({ title: '操作失败', icon: 'error' });
        }
        uni.hideLoading();
      }
    }
  });
};

const appointPlayer = async (user) => {
  uni.showModal({
    title: '确认任命',
    content: `确定要将 ${user.nickname} 任命为打手吗？`,
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '处理中...' });
        try {
          const result = await appointPlayerApi(user.id);
          if (result.code === 200) {
            uni.showToast({ title: result.msg, icon: 'success' });
            loadUsers();
          } else {
            uni.showToast({ title: result.msg, icon: 'error' });
          }
        } catch (e) {
          uni.showToast({ title: '操作失败', icon: 'error' });
        }
        uni.hideLoading();
      }
    }
  });
};

const showFineDialog = (user) => {
  fineTarget.value = user<template>
  <view class="page">
    <view class="header">
      <text class="title">财务流水</text>
      <text class="subtitle">订单流水 · 提现流水 · 罚款记录</text>
    </view>
    
    <!-- Tab 切换 -->
    <view class="tabs">
      <view class="tab" :class="{ active: activeTab === 'orders' }" @click="activeTab = 'orders'">订单流水</view>
      <view class="tab" :class="{ active: activeTab === 'withdraws' }" @click="activeTab = 'withdraws'">提现流水</view>
      <view class="tab" :class="{ active: activeTab === 'fines' }" @click="activeTab = 'fines'">罚款记录</view>
    </view>
    
    <!-- 统计卡片 -->
    <view class="stats-row">
      <view class="stat-item">
        <text class="stat-label">订单总额</text>
        <text class="stat-value">¥{{ statistics.total_order_amount }}</text>
      </view>
      <view class="stat-item">
        <text class="stat-label">平台抽成</text>
        <text class="stat-value">¥{{ statistics.total_platform_fee }}</text>
      </view>
      <view class="stat-item">
        <text class="stat-label">提现总额</text>
        <text class="stat-value">¥{{ statistics.total_withdraw_amount }}</text>
      </view>
      <view class="stat-item">
        <text class="stat-label">罚款总额</text>
        <text class="stat-value">¥{{ statistics.total_fine_amount }}</text>
      </view>
    </view>
    
    <!-- 订单流水列表 -->
    <view class="list" v-if="activeTab === 'orders'">
      <view class="list-item" v-for="order in orders" :key="order.id">
        <view class="item-header">
          <text class="order-sn">{{ order.order_sn }}</text>
          <view class="status" :class="getOrderStatusClass(order.status)">
            {{ getOrderStatus(order.status) }}
          </view>
        </view>
        <view class="item-content">
          <text>金额: ¥{{ order.price }}</text>
          <text>平台抽成: ¥{{ order.platform_fee }}</text>
          <text>打手收入: ¥{{ order.player_income }}</text>
        </view>
        <view class="item-footer">
          <text>创建时间: {{ order.create_time }}</text>
          <text v-if="order.complete_time">完成时间: {{ order.complete_time }}</text>
        </view>
      </view>
      <view class="empty" v-if="orders.length === 0">暂无订单数据</view>
    </view>
    
    <!-- 提现流水列表 -->
    <view class="list" v-if="activeTab === 'withdraws'">
      <view class="list-item" v-for="withdraw in withdraws" :key="withdraw.id">
        <view class="item-header">
          <text class="user-name">{{ withdraw.nickname }}</text>
          <view class="status" :class="getWithdrawStatusClass(withdraw.status)">
            {{ getWithdrawStatus(withdraw.status) }}
          </view>
        </view>
        <view class="item-content">
          <text>金额: ¥{{ withdraw.amount }}</text>
          <image class="proof-img" :src="withdraw.image_url" mode="aspectFill" @click="previewImage(withdraw.image_url)"></image>
        </view>
        <view class="item-footer">
          <text>申请时间: {{ withdraw.apply_time }}</text>
          <text v-if="withdraw.process_time">处理时间: {{ withdraw.process_time }}</text>
        </view>
      </view>
      <view class="empty" v-if="withdraws.length === 0">暂无提现数据</view>
    </view>
    
    <!-- 罚款记录列表 -->
    <view class="list" v-if="activeTab === 'fines'">
      <view class="list-item" v-for="fine in punishments" :key="fine.id">
        <view class="item-header">
          <text class="user-name">{{ fine.nickname }}</text>
          <view class="status fine">罚款</view>
        </view>
        <view class="item-content">
          <text>金额: ¥{{ fine.amount }}</text>
          <text>原因: {{ fine.reason }}</text>
        </view>
        <view class="item-footer">
          <text>时间: {{ fine.create_time }}</text>
        </view>
      </view>
      <view class="empty" v-if="punishments.length === 0">暂无罚款记录</view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getFinancialData } from '@/api/admin';

const activeTab = ref('orders');
const statistics = ref({
  total_order_amount: 0,
  total_platform_fee: 0,
  total_withdraw_amount: 0,
  total_fine_amount: 0
});
const orders = ref([]);
const withdraws = ref([]);
const punishments = ref([]);

const getOrderStatus = (status) => {
  const map = { 0: '待接单', 1: '进行中', 2: '已完成', 3: '已取消', 4: '退单中' };
  return map[status] || '未知';
};

const getOrderStatusClass = (status) => {
  if (status === 2) return 'completed';
  if (status === 0) return 'pending';
  return 'other';
};

const getWithdrawStatus = (status) => {
  const map = { 0: '待处理', 1: '已打款', 2: '已拒绝' };
  return map[status] || '未知';
};

const getWithdrawStatusClass = (status) => {
  if (status === 1) return 'completed';
  if (status === 0) return 'pending';
  return 'rejected';
};

const previewImage = (url) => {
  uni.previewImage({ urls: [url] });
};

const loadData = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getFinancialData();
    if (res.code === 200) {
      statistics.value = res.data.statistics;
      orders.value = res.data.orders;
      withdraws.value = res.data.withdraws;
      punishments.value = res.data.punishments;
    }
  } catch (e) {
    uni.showToast({ title: '加载失败', icon: 'error' });
  }
  uni.hideLoading();
};

onShow(() => {
  loadData();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.header {
  margin-bottom: 30rpx;
  
  .title {
    font-size: 40rpx;
    font-weight: bold;
    display: block;
  }
  
  .subtitle {
    font-size: 24rpx;
    color: #999;
  }
}

.tabs {
  display: flex;
  background: white;
  border-radius: 50rpx;
  margin-bottom: 30rpx;
  
  .tab {
    flex: 1;
    text-align: center;
    padding: 20rpx;
    font-size: 28rpx;
    color: #666;
    
    &.active {
      background: #FF6B35;
      color: white;
      border-radius: 50rpx;
    }
  }
}

.stats-row {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20rpx;
  margin-bottom: 30rpx;
  
  .stat-item {
    background: white;
    border-radius: 20rpx;
    padding: 24rpx;
    text-align: center;
    
    .stat-label {
      font-size: 24rpx;
      color: #999;
      display: block;
      margin-bottom: 12rpx;
    }
    
    .stat-value {
      font-size: 36rpx;
      font-weight: bold;
      color: #FF6B35;
    }
  }
}

.list {
  .list-item {
    background: white;
    border-radius: 20rpx;
    padding: 24rpx;
    margin-bottom: 20rpx;
    
    .item-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16rpx;
      
      .order-sn, .user-name {
        font-size: 28rpx;
        font-weight: bold;
      }
      
      .status {
        padding: 6rpx 20rpx;
        border-radius: 30rpx;
        font-size: 22rpx;
        
        &.completed { background: #4CAF50; color: white; }
        &.pending { background: #FF9800; color: white; }
        &.rejected { background: #f44336; color: white; }
        &.fine { background: #f44336; color: white; }
        &.other { background: #9<template>
  <view class="page">
    <view class="header">
      <text class="title">提现处理</text>
      <text class="subtitle">打手提现申请 · 管理员审核打款</text>
    </view>
    
    <!-- 待处理列表 -->
    <view class="list">
      <view class="list-item" v-for="item in pendingList" :key="item.id">
        <view class="item-header">
          <text class="user-name">{{ item.nickname }}</text>
          <text class="amount">¥{{ item.amount }}</text>
        </view>
        <view class="item-content">
          <text>余额: ¥{{ item.balance }}</text>
          <image class="proof-img" :src="item.image_url" mode="aspectFill" @click="previewImage(item.image_url)"></image>
        </view>
        <view class="item-footer">
          <text>申请时间: {{ item.apply_time }}</text>
        </view>
        <view class="actions">
          <button class="reject-btn" @click="processWithdraw(item, 'reject')">拒绝</button>
          <button class="approve-btn" @click="processWithdraw(item, 'approve')">确认打款</button>
        </view>
      </view>
      
      <view class="empty" v-if="pendingList.length === 0">
        <text>暂无待处理提现申请</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getPendingWithdraws, processWithdrawApi } from '@/api/admin';

const pendingList = ref([]);

const previewImage = (url) => {
  uni.previewImage({ urls: [url] });
};

const loadData = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getPendingWithdraws();
    if (res.code === 200) {
      pendingList.value = res.data;
    }
  } catch (e) {
    uni.showToast({ title: '加载失败', icon: 'error' });
  }
  uni.hideLoading();
};

const processWithdraw = (item, action) => {
  const title = action === 'approve' ? '确认打款' : '拒绝提现';
  const content = action === 'approve' 
    ? `确定要向 ${item.nickname} 打款 ¥${item.amount} 吗？` 
    : `确定要拒绝 ${item.nickname} 的提现申请吗？`;
    
  uni.showModal({
    title,
    content,
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '处理中...' });
        try {
          const result = await processWithdrawApi(item.id, action);
          if (result.code === 200) {
            uni.showToast({ title: result.msg, icon: 'success' });
            loadData();
          } else {
            uni.showToast({ title: result.msg, icon: 'error' });
          }
        } catch (e) {
          uni.showToast({ title: '操作失败', icon: 'error' });
        }
        uni.hideLoading();
      }
    }
  });
};

onShow(() => {
  loadData();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.header {
  margin-bottom: 30rpx;
  
  .title {
    font-size: 40rpx;
    font-weight: bold;
    display: block;
  }
  
  .subtitle {
    font-size: 24rpx;
    color: #999;
  }
}

.list {
  .list-item {
    background: white;
    border-radius: 20rpx;
    padding: 24rpx;
    margin-bottom: 20rpx;
    
    .item-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16rpx;
      
      .user-name {
        font-size: 30rpx;
        font-weight: bold;
      }
      
      .amount {
        font-size: 32rpx;
        font-weight: bold;
        color: #FF6B35;
      }
    }
    
    .item-content {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16rpx;
      font-size: 26rpx;
      color: #666;
      
      .proof-img {
        width: 100rpx;
        height: 100rpx;
        border-radius: 12rpx;
      }
    }
    
    .item-footer {
      font-size: 22rpx;
      color: #999;
      margin-bottom: 20rpx;
    }
    
    .actions {
      display: flex;
      gap: 20rpx;
      
      button {
        flex: 1;
        padding: 20rpx;
        border-radius: 50rpx;
        font-size: 28rpx;
        
        &.reject-btn {
          background: #f5f5f5;
          color: #666;
        }
        
        &.approve-btn {
          background: #FF6B35;
          color: white;
        }
      }
    }
  }
}

.empty {
  text-align: center;
  padding: 100rpx;
  color: #999;
}
</style>// api/index.js - 统一导出所有API
export * from './user';
export * from './order';
export * from './admin';
export * from './withdraw';
export * from './club';
export * from './message';// api/user.js
import request from './request';

// 微信/QQ登录
export const login = (loginType, openid, nickname) => {
  return request({
    url: '/user/login',
    method: 'POST',
    data: { login_type: loginType, openid, nickname }
  });
};

// 游客登录
export const guestLogin = () => {
  return request({
    url: '/user/guest',
    method: 'POST'
  });
};

// 获取用户信息
export const getUserInfo = () => {
  return request({
    url: '/user/info',
    method: 'GET'
  });
};

// 修改昵称
export const updateNickname = (nickname) => {
  return request({
    url: '/user/nickname',
    method: 'POST',
    data: { nickname }
  });
};

// 检查是否为管理员
export const checkAdmin = () => {
  return request({
    url: '/admin/check',
    method: 'GET'
  });
};

// 管理员密码解锁
export const unlockAdmin = (password) => {
  return request({
    url: '/admin/unlock',
    method: 'POST',
    data: { password }
  });
};// api/order.js
import request from './request';

// 发布订单（购买单子）
export const createOrder = (data) => {
  return request({
    url: '/order/create',
    method: 'POST',
    data
  });
};

// 获取可接单列表
export const getAvailableOrders = () => {
  return request({
    url: '/order/available',
    method: 'GET'
  });
};

// 打手接单
export const grabOrder = (orderId) => {
  return request({
    url: '/order/grab',
    method: 'POST',
    data: { order_id: orderId }
  });
};

// 打手退单
export const cancelOrder = (orderId, reason) => {
  return request({
    url: '/order/cancel',
    method: 'POST',
    data: { order_id: orderId, reason }
  });
};

// 打手存单
export const saveOrder = (orderId) => {
  return request({
    url: '/order/save',
    method: 'POST',
    data: { order_id: orderId }
  });
};

// 打手完成订单
export const completeOrder = (orderId) => {
  return request({
    url: '/order/complete',
    method: 'POST',
    data: { order_id: orderId }
  });
};

// 获取我的订单（老板视角）
export const getMyOrders = () => {
  return request({
    url: '/order/my',
    method: 'GET'
  });
};

// 获取我接的订单（打手视角）
export const getMyGrabOrders = () => {
  return request({
    url: '/order/my-grab',
    method: 'GET'
  });
};

// 获取订单详情
export const getOrderDetail = (orderId) => {
  return request({
    url: '/order/detail',
    method: 'GET',
    data: { order_id: orderId }
  });
};// api/admin.js
import request from './request';

// 获取用户列表
export const getUserList = () => {
  return request({
    url: '/admin/users',
    method: 'GET'
  });
};

// 任命为成员
export const appointMember = (userId) => {
  return request({
    url: '/admin/appoint-member',
    method: 'POST',
    data: { user_id: userId }
  });
};

// 任命为打手
export const appointPlayer = (userId) => {
  return request({
    url: '/admin/appoint-player',
    method: 'POST',
    data: { user_id: userId }
  });
};

// 罚款
export const fineUser = (userId, amount, reason) => {
  return request({
    url: '/admin/fine',
    method: 'POST',
    data: { user_id: userId, amount, reason }
  });
};

// 踢出/封禁用户
export const kickUser = (userId) => {
  return request({
    url: '/admin/kick',
    method: 'POST',
    data: { user_id: userId }
  });
};

// 解封用户
export const unbanUser = (userId) => {
  return request({
    url: '/admin/unban',
    method: 'POST',
    data: { user_id: userId }
  });
};

// 获取财务流水数据
export const getFinancialData = () => {
  return request({
    url: '/admin/finance',
    method: 'GET'
  });
};

// 获取待处理提现申请
export const getPendingWithdraws = () => {
  return request({
    url: '/admin/withdraw-pending',
    method: 'GET'
  });
};

// 处理提现申请
export const processWithdraw = (withdrawId, action, remark = '') => {
  return request({
    url: '/admin/process-withdraw',
    method: 'POST',
    data: { withdraw_id: withdrawId, action, remark }
  });
};// api/request.js
const BASE_URL = 'https://your-api-domain.com/api'; // 替换为实际后端地址

const request = (options) => {
  return new Promise((resolve, reject) => {
    const token = uni.getStorageSync('token');
    
    uni.request({
      url: BASE_URL + options.url,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Authorization': token ? `Bearer ${token}` : '',
        'Content-Type': options.header?.['Content-Type'] || 'application/json'
      },
      timeout: 30000,
      success: (res) => {
        if (res.statusCode === 200) {
          if (res.data.code === 200) {
            resolve(res.data);
          } else if (res.data.code === 401) {
            // token过期，清除登录状态
            uni.removeStorageSync('token');
            uni.showToast({ title: '请重新登录', icon: 'none' });
            setTimeout(() => {
              uni.reLaunch({ url: '/pages/login/index' });
            }, 1500);
            reject(res.data.msg);
          } else {
            uni.showToast({ title: res.data.msg || '请求失败', icon: 'none' });
            reject(res.data.msg);
          }
        } else {
          uni.showToast({ title: '网络错误', icon: 'none' });
          reject('网络错误');
        }
      },
      fail: (err) => {
        uni.showToast({ title: '网络连接失败', icon: 'none' });
        reject(err);
      }
    });
  });
};

export default request;// api/withdraw.js
import request from './request';

// 申请提现（需上传图片）
export const applyWithdraw = (amount, imageFile) => {
  const formData = new FormData();
  formData.append('amount', amount);
  formData.append('image', imageFile);
  
  return request({
    url: '/withdraw/apply',
    method: 'POST',
    data: formData,
    header: { 'Content-Type': 'multipart/form-data' }
  });
};

// 获取我的提现记录
export const getMyWithdrawList = () => {
  return request({
    url: '/withdraw/my',
    method: 'GET'
  });
};

// 获取当前余额
export const getBalance = () => {
  return request({
    url: '/withdraw/balance',
    method: 'GET'
  });
};<template>
  <view class="page">
    <view class="logo-area">
      <image class="logo" src="/static/logo.png" mode="aspectFit"></image>
      <text class="app-name">txy电竞</text>
      <text class="slogan">暗区突围 · 专业俱乐部</text>
    </view>
    
    <view class="login-buttons">
      <button class="login-btn wechat" @click="handleLogin('wechat')">
        <text>微信登录</text>
      </button>
      <button class="login-btn qq" @click="handleLogin('qq')">
        <text>QQ登录</text>
      </button>
      <button class="login-btn guest" @click="handleGuestLogin">
        <text>游客体验</text>
      </button>
    </view>
    
    <view class="agreement">
      <text>登录即代表同意《用户协议》和《隐私政策》</text>
    </view>
  </view>
</template>

<script setup>
import { login, guestLogin } from '@/api/user';

const handleLogin = async (type) => {
  uni.showLoading({ title: '登录中...' });
  
  // 模拟获取openid（实际开发中需要调用微信/QQ SDK）
  const mockOpenid = `${type}_${Date.now()}_${Math.random().toString(36).substr(2, 8)}`;
  const nickname = '';
  
  try {
    const res = await login(type, mockOpenid, nickname);
    if (res.code === 200) {
      uni.setStorageSync('token', res.data.token);
      uni.showToast({ title: '登录成功', icon: 'success' });
      setTimeout(() => {
        uni.switchTab({ url: '/pages/index/index' });
      }, 1000);
    }
  } catch (e) {
    uni.showToast({ title: '登录失败', icon: 'error' });
  }
  uni.hideLoading();
};

const handleGuestLogin = async () => {
  uni.showLoading({ title: '进入中...' });
  try {
    const res = await guestLogin();
    if (res.code === 200) {
      uni.setStorageSync('token', res.data.token);
      uni.showToast({ title: '欢迎游客', icon: 'success' });
      setTimeout(() => {
        uni.switchTab({ url: '/pages/index/index' });
      }, 1000);
    }
  } catch (e) {
    uni.showToast({ title: '进入失败', icon: 'error' });
  }
  uni.hideLoading();
};
</script>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60rpx;
}

.logo-area {
  text-align: center;
  margin-bottom: 120rpx;
  
  .logo {
    width: 160rpx;
    height: 160rpx;
    margin-bottom: 30rpx;
  }
  
  .app-name {
    font-size: 48rpx;
    font-weight: bold;
    color: white;
    display: block;
    margin-bottom: 16rpx;
  }
  
  .slogan {
    font-size: 26rpx;
    color: rgba(255,255,255,0.7);
  }
}

.login-buttons {
  width: 100%;
  margin-bottom: 60rpx;
  
  .login-btn {
    width: 100%;
    padding: 28rpx;
    border-radius: 60rpx;
    margin-bottom: 30rpx;
    font-size: 32rpx;
    font-weight: 500;
    
    &.wechat {
      background: #07C160;
      color: white;
    }
    
    &.qq {
      background: #12B7F5;
      color: white;
    }
    
    &.guest {
      background: transparent;
      border: 2rpx solid rgba(255,255,255,0.5);
      color: white;
    }
  }
}

.agreement {
  text-align: center;
  font-size: 24rpx;
  color: rgba(255,255,255,0.5);
}
</style><template>
  <view class="page">
    <view class="header">
      <text class="title">抢单大厅</text>
      <text class="subtitle" v-if="!isPlayer">仅打手可接单，请联系管理员认证</text>
      <text class="subtitle" v-else>实时订单，手慢无</text>
    </view>
    
    <!-- 筛选栏 -->
    <view class="filter-bar" v-if="isPlayer">
      <view class="filter-item" :class="{ active: filterMap === '' }" @click="filterMap = ''">全部地图</view>
      <view class="filter-item" :class="{ active: filterMap === map }" v-for="map in mapList" :key="map" @click="filterMap = map">
        {{ map }}
      </view>
    </view>
    
    <!-- 订单列表 -->
    <view class="order-list" v-if="isPlayer">
      <view class="order-card" v-for="order in filteredOrders" :key="order.id">
        <view class="order-header">
          <text class="map-name">{{ order.game_map || '未知地图' }}</text>
          <text class="price">¥{{ order.price }}</text>
        </view>
        <view class="order-type">
          <text class="type-tag">{{ getServiceType(order.service_type) }}</text>
        </view>
        <view class="order-remark" v-if="order.remark">
          <text>备注：{{ order.remark }}</text>
        </view>
        <view class="order-footer">
          <text class="time">{{ order.create_time }}</text>
          <button class="grab-btn" @click="doGrab(order.id)">立即抢单</button>
        </view>
      </view>
      
      <view class="empty" v-if="filteredOrders.length === 0">
        <text>暂无可用订单</text>
      </view>
    </view>
    
    <!-- 非打手提示 -->
    <view class="not-player" v-else>
      <text class="icon">🔒</text>
      <text class="msg">您还不是打手，无法接单</text>
      <text class="hint">请联系管理员认证成为打手</text>
    </view>
  </view>
</template>

<script setup>
import { ref, computed, onShow } from 'vue';
import { getAvailableOrders, grabOrder } from '@/api/order';
import { getUserInfo } from '@/api/user';

const orders = ref([]);
const isPlayer = ref(false);
const filterMap = ref('');

const mapList = ['农场', '山谷', '北部山区', '电视台', '军港'];

const filteredOrders = computed(() => {
  if (filterMap.value === '') return orders.value;
  return orders.value.filter(o => o.game_map === filterMap.value);
});

const getServiceType = (type) => {
  const map = { 1: '护航', 2: '代练', 3: '教学' };
  return map[type] || '未知';
};

const loadOrders = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getAvailableOrders();
    if (res.code === 200) {
      orders.value = res.data;
    }
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const checkPlayerStatus = async () => {
  try {
    const res = await getUserInfo();
    if (res.code === 200) {
      isPlayer.value = res.data.level === 1 || res.data.level === 3;
    }
  } catch (e) {
    console.error(e);
  }
};

const doGrab = async (orderId) => {
  uni.showModal({
    title: '确认接单',
    content: '确定要接这个订单吗？',
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '抢单中...' });
        try {
          const result = await grabOrder(orderId);
          if (result.code === 200) {
            uni.showToast({ title: result.msg, icon: 'success' });
            loadOrders();
          } else {
            uni.showToast({ title: result.msg, icon: 'error' });
          }
        } catch (e) {
          uni.showToast({ title: '抢单失败', icon: 'error' });
        }
        uni.hideLoading();
      }
    }
  });
};

onShow(() => {
  checkPlayerStatus();
  if (isPlayer.value) {
    loadOrders();
  }
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.header {
  margin-bottom: 30rpx;
  
  .title {
    font-size: 40rpx;
    font-weight: bold;
    display: block;
  }
  
  .subtitle {
    font-size: 24rpx;
    color: #999;
  }
}

.filter-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
  margin-bottom: 30rpx;
  
  .filter-item {
    padding: 12rpx 28rpx;
    background: #f5f5f5;
    border-radius: 50rpx;
    font-size: 26rpx;
    color: #666;
    
    &.active {
      background: #FF6B35;
      color: white;
    }
  }
}

.order-list {
  .order-card {
    background: white;
    border-radius: 20rpx;
    padding: 24rpx;
    margin-bottom: 20rpx;
    
    .order-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16rpx;
      
      .map-name {
        font-size: 32rpx;
        font-weight: bold;
      }
      
      .price {
        font-size: 36rpx;
        font-weight: bold;
        color: #FF6B35;
      }
    }
    
    .order-type {
      margin-bottom: 16rpx;
      
      .type-tag {
        background: #f0f0f0;
        padding: 8rpx 20rpx;
        border-radius: 30rpx;
        font-size: 24rpx;
        color: #666;
      }
    }
    
    .order-remark {
      font-size: 26rpx;
      color: #999;
      margin-bottom: 16rpx;
    }
    
    .order-footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      
      .time {
        font-size: 22rpx;
        color: #999;
      }
      
      .grab-btn {
        background: #FF6B35;
        color: white;
        border: none;
        padding: 12rpx 32rpx;
        border-radius: 50rpx;
        font-size: 26rpx;
      }
    }
  }
}

.empty, .not-player {
  text-align: center;
  padding: 100rpx;
  color: #999;
  
  .icon {
    font-size: 80rpx;
    display: block;
    margin-bottom: 30rpx;
  }
  
  .msg {
    font-size: 30rpx;
    display: block;
    margin-bottom: 16rpx;
  }
  
  .hint {
    font-size: 24rpx;
  }
}
</style><template>
  <view class="page">
    <view class="header">
      <text class="title">提现申请</text>
      <text class="subtitle">仅限打手 · 每天8:00-9:00开放</text>
    </view>
    
    <!-- 余额信息 -->
    <view class="balance-card">
      <text class="label">当前余额</text>
      <text class="amount">¥{{ balance }}</text>
      <view class="time-status" :class="{ valid: canWithdraw }">
        {{ canWithdraw ? '提现时段内 ✓' : '非提现时段，请在8:00-9:00申请' }}
      </view>
    </view>
    
    <!-- 提现表单 -->
    <view class="form-card" v-if="canWithdraw">
      <view class="form-item">
        <text class="label">提现金额</text>
        <input 
          class="input" 
          type="digit" 
          v-model="amount" 
          placeholder="请输入提现金额"
          :max="balance"
        />
        <text class="unit">元</text>
      </view>
      
      <view class="form-item">
        <text class="label">上传凭证</text>
        <view class="upload-area" @click="chooseImage">
          <image v-if="imageUrl" :src="imageUrl" mode="aspectFill" class="preview-img"></image>
          <view v-else class="upload-placeholder">
            <text class="icon">📷</text>
            <text>点击上传收款码截图</text>
          </view>
        </view>
      </view>
      
      <button class="submit-btn" @click="submitWithdraw" :disabled="!canSubmit">提交申请</button>
    </view>
    
    <!-- 非打手提示 -->
    <view class="not-player" v-else-if="!isPlayer">
      <text class="icon">🔒</text>
      <text class="msg">仅打手可提现</text>
      <text class="hint">请联系管理员认证成为打手</text>
    </view>
  </view>
</template>

<script setup>
import { ref, computed, onShow } from 'vue';
import { getBalance, applyWithdraw } from '@/api/withdraw';
import { getUserInfo } from '@/api/user';

const balance = ref(0);
const isPlayer = ref(false);
const canWithdraw = ref(false);
const amount = ref('');
const imageFile = ref(null);
const imageUrl = ref('');

const canSubmit = computed(() => {
  return amount.value > 0 && amount.value <= balance.value && imageFile.value;
});

const loadData = async () => {
  try {
    const [balanceRes, userRes] = await Promise.all([
      getBalance(),
      getUserInfo()
    ]);
    if (balanceRes.code === 200) {
      balance.value = balanceRes.data.balance;
      canWithdraw.value = balanceRes.data.withdraw_time_valid;
    }
    if (userRes.code === 200) {
      isPlayer.value = userRes.data.level === 1 || userRes.data.level === 3;
    }
  } catch (e) {
    console.error(e);
  }
};

const chooseImage = () => {
  uni.chooseImage({
    count: 1,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: (res) => {
      const tempFilePath = res.tempFilePaths[0];
      imageUrl.value = tempFilePath;
      
      // 转换为文件对象用于上传
      uni.getFileInfo({
        filePath: tempFilePath,
        success: (info) => {
          imageFile.value = {
            path: tempFilePath,
            size: info.size,
            name: 'withdraw_' + Date.now() + '.jpg'
          };
        }
      });
    }
  });
};

const submitWithdraw = async () => {
  if (!canSubmit.value) return;
  
  uni.showLoading({ title: '提交中...' });
  try {
    // 将图片路径转为Blob上传
    const res = await new Promise((resolve, reject) => {
      uni.uploadFile({
        url: 'https://your-api-domain.com/api/withdraw/apply',
        filePath: imageFile.value.path,
        name: 'image',
        formData: { amount: amount.value },
        header: {
          'Authorization': 'Bearer ' + uni.getStorageSync('token')
        },
        success: (uploadRes) => {
          const data = JSON.parse(uploadRes.data);
          resolve(data);
        },
        fail: reject
      });
    });
    
    if (res.code === 200) {
      uni.showToast({ title: res.msg, icon: 'success' });
      setTimeout(() => {
        uni.navigateBack();
      }, 1500);
    } else {
      uni.showToast({ title: res.msg, icon: 'error' });
    }
  } catch (e) {
    uni.showToast({ title: '提交失败', icon: 'error' });
  }
  uni.hideLoading();
};

onShow(() => {
  loadData();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.header {
  margin-bottom: 30rpx;
  
  .title {
    font-size: 40rpx;
    font-weight: bold;
    display: block;
  }
  
  .subtitle {
    font-size: 24rpx;
    color: #999;
  }
}

.balance-card {
  background: linear-gradient(135deg, #1a1a2e, #16213e);
  border-radius: 24rpx;
  padding: 40rpx;
  text-align: center;
  margin-bottom: 30rpx;
  
  .label {
    font-size: 26rpx;
    color: rgba(255,255,255,0.7);
    display: block;
    margin-bottom: 16rpx;
  }
  
  .amount {
    font-size: 64rpx;
    font-weight: bold;
    color: #FFD700;
    display: block;
    margin-bottom: 20rpx;
  }
  
  .time-status {
    font-size: 24rpx;
    padding: 8rpx 20rpx;
    border-radius: 30rpx;
    display: inline-block;
    
    &.valid {
      background: rgba(76, 175, 80, 0.2);
      color: #4CAF50;
    }
    
    &:not(.valid) {
      background: rgba(244, 67, 54, 0.2);
      color: #f44336;
    }
  }
}

.form-card {
  background: white;
  border-radius: 24rpx;
  padding: 30rpx;
  
  .form-item {
    margin-bottom: 40rpx;
    
    .label {
      font-size: 28rpx;
      font-weight: bold;
      display: block;
      margin-bottom: 16rpx;
    }
    
    .input {
      border: 1rpx solid #ddd;
      border-radius: 16rpx;
      padding: 24rpx;
      font-size: 32rpx;
    }
    
    .upload-area {
      width: 100%;
      min-height: 200rpx;
      background: #f5f5f5;
      border-radius: 16rpx;
      display: flex;
      align-items: center;
      justify-content: center;
      
      .preview-img {
        width: 100%;
        height: 200rpx;
        border-radius: 16rpx;
      }
      
      .upload-placeholder {
        text-align: center;
        
        .icon {
          font-size: 60rpx;
          display: block;
          margin-bottom: 16rpx;
        }
        
        text {
          font-size: 24rpx;
          color: #999;
        }
      }
    }
  }
  
  .submit-btn {
    background: #FF6B35;
    color: white;
    border: none;
    border-radius: 50rpx;
    padding: 28rpx;
    font-size: 32rpx;
    
    &[disabled] {
      opacity: 0.5;
    }
  }
}

.not-player {
  text-align: center;
  padding: 100rpx;
  
  .icon {
    font-size: 80rpx;
    display: block;
    margin-bottom: 30rpx;
  }
  
  .msg {
    font-size: 30rpx;
    display: block;
    margin-bottom: 16rpx;
  }
  
  .hint {
    font-size: 24rpx;
    color: #999;
  }
}
</style>-- =============================================
-- 扩展配置表（管理员可配置栏目）
-- =============================================

-- 1. Banner配置表
DROP TABLE IF EXISTS `txy_banner`;
CREATE TABLE `txy_banner` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(100) DEFAULT NULL,
  `image` varchar(500) NOT NULL,
  `link_url` varchar(500) DEFAULT NULL,
  `sort` int(11) DEFAULT 0,
  `status` tinyint(1) DEFAULT 1,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Banner配置表';

-- 2. 功能入口配置表（首页宫格菜单）
DROP TABLE IF EXISTS `txy_menu`;
CREATE TABLE `txy_menu` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '菜单名称',
  `icon` varchar(500) NOT NULL COMMENT '图标URL',
  `link_url` varchar(500) NOT NULL COMMENT '跳转链接',
  `sort` int(11) DEFAULT 0,
  `status` tinyint(1) DEFAULT 1,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='功能入口配置表';

-- 插入默认菜单
INSERT INTO `txy_menu` (`name`, `icon`, `link_url`, `sort`) VALUES
('发布订单', '/static/menu/order.png', '/pages/order/create', 1),
('抢单大厅', '/static/menu/grab.png', '/pages/player/grab', 2),
('俱乐部', '/static/menu/club.png', '/pages/club/list', 3),
('我的订单', '/static/menu/myorder.png', '/pages/order/list', 4);

-- 3. 公告表
DROP TABLE IF EXISTS `txy_notice`;
CREATE TABLE `txy_notice` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(200) NOT NULL,
  `content` varchar(1000) DEFAULT NULL,
  `sort` int(11) DEFAULT 0,
  `status` tinyint(1) DEFAULT 1,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='公告表';

INSERT INTO `txy_notice` (`title`, `content`, `sort`) VALUES
('欢迎加入txy电竞', '暗区突围专业俱乐部，护航/代练/教学一站式服务', 1),
('打手招募中', '认证打手可接单赚钱，联系管理员申请', 2);

-- 4. 首页打手推荐配置表
DROP TABLE IF EXISTS `txy_hot_player`;
CREATE TABLE `txy_hot_player` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `sort` int(11) DEFAULT 0,
  `status` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='首页打手推荐表';<template>
  <view class="page">
    <!-- 轮播图（从API加载） -->
    <swiper class="banner" :indicator-dots="true" :autoplay="true" :interval="3000" v-if="banners.length">
      <swiper-item v-for="item in banners" :key="item.id">
        <image :src="item.image" mode="aspectFill" class="banner-img" @click="goToUrl(item.link_url)"></image>
      </swiper-item>
    </swiper>
    
    <!-- 功能入口（从API加载） -->
    <view class="menu-grid" v-if="menus.length">
      <view class="menu-item" v-for="menu in menus" :key="menu.id" @click="goToUrl(menu.link_url)">
        <image :src="menu.icon" class="menu-icon" mode="aspectFit"></image>
        <text class="menu-name">{{ menu.name }}</text>
      </view>
    </view>
    
    <!-- 公告滚动（从API加载） -->
    <view class="notice-bar" v-if="notices.length">
      <text class="notice-icon">📢</text>
      <swiper class="notice-swiper" vertical autoplay :interval="3000" :circular="true">
        <swiper-item v-for="notice in notices" :key="notice.id">
          <text class="notice-text" @click="showNotice(notice)">{{ notice.title }}</text>
        </swiper-item>
      </swiper>
    </view>
    
    <!-- 推荐打手（从API加载） -->
    <view class="section" v-if="hotPlayers.length">
      <view class="section-header">
        <text class="section-title">⭐ 明星打手</text>
        <text class="section-more" @click="goTo('/pages/player/rank')">更多</text>
      </view>
      <scroll-view scroll-x class="player-scroll">
        <view class="player-card" v-for="player in hotPlayers" :key="player.id" @click="goToPlayer(player.id)">
          <image :src="player.avatar || '/static/default-avatar.png'" class="player-avatar" mode="aspectFill"></image>
          <text class="player-name">{{ player.nickname }}</text>
          <text class="player-earned">收入 ¥{{ player.total_earned || 0 }}</text>
        </view>
      </scroll-view>
    </view>
    
    <!-- 快速入口 -->
    <view class="section">
      <view class="section-header">
        <text class="section-title">快速服务</text>
      </view>
      <view class="service-list">
        <view class="service-item" @click="goTo('/pages/order/create')">
          <text class="service-icon">📝</text>
          <text class="service-name">发布订单</text>
          <text class="service-desc">老板发布，打手接单</text>
        </view>
        <view class="service-item" @click="goTo('/pages/player/grab')">
          <text class="service-icon">⚡</text>
          <text class="service-name">抢单大厅</text>
          <text class="service-desc">打手接单赚钱</text>
        </view>
        <view class="service-item" @click="goTo('/pages/club/list')">
          <text class="service-icon">🏛️</text>
          <text class="service-name">加入俱乐部</text>
          <text class="service-desc">找到组织一起玩</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getBanners, getMenus, getNotices, getHotPlayers } from '@/api/config';

const banners = ref([]);
const menus = ref([]);
const notices = ref([]);
const hotPlayers = ref([]);

const loadConfig = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const [bannerRes, menuRes, noticeRes, playerRes] = await Promise.all([
      getBanners(),
      getMenus(),
      getNotices(),
      getHotPlayers()
    ]);
    
    if (bannerRes.code === 200) banners.value = bannerRes.data;
    if (menuRes.code === 200) menus.value = menuRes.data;
    if (noticeRes.code === 200) notices.value = noticeRes.data;
    if (playerRes.code === 200) hotPlayers.value = playerRes.data;
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const goToUrl = (url) => {
  if (!url) return;
  if (url.startsWith('http')) {
    // 外链
    uni.setClipboardData({
      data: url,
      success: () => uni.showToast({ title: '链接已复制', icon: 'none' })
    });
  } else {
    uni.navigateTo({ url });
  }
};

const goTo = (url) => {
  uni.navigateTo({ url });
};

const goToPlayer = (id) => {
  uni.navigateTo({ url: `/pages/player/detail?id=${id}` });
};

const showNotice = (notice) => {
  uni.showModal({
    title: notice.title,
    content: notice.content,
    showCancel: false
  });
};

onShow(() => {
  loadConfig();
});
</script>

<style lang="scss" scoped>
.page {
  padding-bottom: 100rpx;
}

.banner {
  width: 100%;
  height: 320rpx;
  
  .banner-img {
    width: 100%;
    height: 100%;
  }
}

.menu-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  background: white;
  margin: 20rpx;
  border-radius: 24rpx;
  padding: 30rpx 0;
  
  .menu-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16rpx;
    
    .menu-icon {
      width: 80rpx;
      height: 80rpx;
    }
    
    .menu-name {
      font-size: 26rpx;
      color: #333;
    }
  }
}

.notice-bar {
  background: #FFF9E8;
  margin: 20rpx;
  border-radius: 50rpx;
  padding: 16rpx 30rpx;
  display: flex;
  align-items: center;
  
  .notice-icon {
    font-size: 32rpx;
    margin-right: 20rpx;
  }
  
  .notice-swiper {
    flex: 1;
    height: 60rpx;
    
    .notice-text {
      font-size: 26rpx;
      color: #FF6B35;
      line-height: 60rpx;
    }
  }
}

.section {
  background: white;
  margin: 20rpx;
  border-radius: 24rpx;
  padding: 20rpx;
  
  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20rpx;
    
    .section-title {
      font-size: 32rpx;
      font-weight: bold;
    }
    
    .section-more {
      font-size: 26rpx;
      color: #999;
    }
  }
}

.player-scroll {
  white-space: nowrap;
  
  .player-card {
    display: inline-block;
    width: 160rpx;
    text-align: center;
    margin-right: 24rpx;
    
    .player-avatar {
      width: 100rpx;
      height: 100rpx;
      border-radius: 50%;
      margin-bottom: 12rpx;
    }
    
    .player-name {
      font-size: 26rpx;
      font-weight: bold;
      display: block;
    }
    
    .player-earned {
      font-size: 22rpx;
      color: #FF6B35;
    }
  }
}

.service-list {
  .service-item {
    display: flex;
    align-items: center;
    padding: 20rpx 0;
    border-bottom: 1rpx solid #f5f5f5;
    
    &:last-child {
      border-bottom: none;
    }
    
    .service-icon {
      font-size: 48rpx;
      margin-right: 24rpx;
    }
    
    .service-name {
      font-size: 30rpx;
      font-weight: bold;
      margin-right: 20rpx;
    }
    
    .service-desc {
      flex: 1;
      font-size: 24rpx;
      color: #999;
    }
  }
}
</style><?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class ConfigController extends BaseController
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
    
    // ========== 获取Banner列表（公开） ==========
    public function getBanners()
    {
        $banners = Db::name('banner')
            ->where('status', 1)
            ->order('sort', 'asc')
            ->select();
        return json(['code' => 200, 'data' => $banners]);
    }
    
    // ========== 管理端：获取所有Banner ==========
    public function getAllBanners()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        $banners = Db::name('banner')->order('sort', 'asc')->select();
        return json(['code' => 200, 'data' => $banners]);
    }
    
    // ========== 管理端：添加Banner ==========
    public function addBanner()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $title = $this->request->post('title');
        $linkUrl = $this->request->post('link_url');
        $image = $this->request->file('image');
        
        if (!$image) {
            return json(['code' => 400, 'msg' => '请上传图片']);
        }
        
        $savePath = 'uploads/banner/' . date('Ymd') . '/';
        $imageName = time() . '_' . rand(1000, 9999) . '.' . $image->extension();
        $image->move($savePath, $imageName);
        
        Db::name('banner')->insert([
            'title' => $title,
            'image' => $savePath . $imageName,
            'link_url' => $linkUrl,
            'sort' => Db::name('banner')->count() + 1,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '添加成功']);
    }
    
    // ========== 管理端：删除Banner ==========
    public function deleteBanner()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $id = $this->request->post('id');
        Db::name('banner')->where('id', $id)->delete();
        
        return json(['code' => 200, 'msg' => '删除成功']);
    }
    
    // ========== 管理端：更新Banner排序 ==========
    public function updateBannerSort()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $ids = $this->request->post('ids');
        foreach ($ids as $index => $id) {
            Db::name('banner')->where('id', $id)->update(['sort' => $index + 1]);
        }
        
        return json(['code' => 200, 'msg' => '排序更新成功']);
    }
    
    // ========== 获取功能菜单（公开） ==========
    public function getMenus()
    {
        $menus = Db::name('menu')
            ->where('status', 1)
            ->order('sort', 'asc')
            ->select();
        return json(['code' => 200, 'data' => $menus]);
    }
    
    // ========== 管理端：获取所有菜单 ==========
    public function getAllMenus()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        $menus = Db::name('menu')->order('sort', 'asc')->select();
        return json(['code' => 200, 'data' => $menus]);
    }
    
    // ========== 管理端：添加/编辑菜单 ==========
    public function saveMenu()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $id = $this->request->post('id');
        $data = [
            'name' => $this->request->post('name'),
            'link_url' => $this->request->post('link_url'),
            'sort' => $this->request->post('sort', 0),
            'status' => $this->request->post('status', 1)
        ];
        
        $image = $this->request->file('icon');
        if ($image) {
            $savePath = 'uploads/menu/';
            $imageName = time() . '_' . rand(1000, 9999) . '.' . $image->extension();
            $image->move($savePath, $imageName);
            $data['icon'] = $savePath . $imageName;
        }
        
        if ($id) {
            Db::name('menu')->where('id', $id)->update($data);
        } else {
            Db::name('menu')->insert($data);
        }
        
        return json(['code' => 200, 'msg' => '保存成功']);
    }
    
    // ========== 管理端：删除菜单 ==========
    public function deleteMenu()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $id = $this->request->post('id');
        Db::name('menu')->where('id', $id)->delete();
        
        return json(['code' => 200, 'msg' => '删除成功']);
    }
    
    // ========== 获取公告列表（公开） ==========
    public function getNotices()
    {
        $notices = Db::name('notice')
            ->where('status', 1)
            ->order('sort', 'asc')
            ->select();
        return json(['code' => 200, 'data' => $notices]);
    }
    
    // ========== 管理端：获取所有公告 ==========
    public function getAllNotices()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        $notices = Db::name('notice')->order('sort', 'asc')->select();
        return json(['code' => 200, 'data' => $notices]);
    }
    
    // ========== 管理端：保存公告 ==========
    public function saveNotice()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $id = $this->request->post('id');
        $data = [
            'title' => $this->request->post('title'),
            'content' => $this->request->post('content'),
            'sort' => $this->request->post('sort', 0),
            'status' => $this->request->post('status', 1)
        ];
        
        if ($id) {
            Db::name('notice')->where('id', $id)->update($data);
        } else {
            Db::name('notice')->insert($data);
        }
        
        return json(['code' => 200, 'msg' => '保存成功']);
    }
    
    // ========== 管理端：删除公告 ==========
    public function deleteNotice()
    {
        if (!$this->checkAdmin()) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $id = $this->request->post('id');
        Db::name('notice')->where('id', $id)->delete();
        
        return json(['code' => 200, 'msg' => '删除成功']);
    }
    
    // ========== 获取首页推荐打手（公开） ==========
    public function getHotPlayers()
    {
        $hotPlayers = Db::name('hot_player')->alias('hp')
            ->join('txy_user u', 'hp.user_id = u.id')
            ->where('hp.st<template>
  <view class="page">
    <view class="header">
      <text class="title">页面配置</text>
      <text class="subtitle">管理Banner、菜单、公告、推荐打手</text>
    </view>
    
    <!-- Tab 切换 -->
    <view class="tabs">
      <view class="tab" :class="{ active: activeTab === 'banner' }" @click="activeTab = 'banner'">Banner</view>
      <view class="tab" :class="{ active: activeTab === 'menu' }" @click="activeTab = 'menu'">功能菜单</view>
      <view class="tab" :class="{ active: activeTab === 'notice' }" @click="activeTab = 'notice'">公告</view>
      <view class="tab" :class="{ active: activeTab === 'hot' }" @click="activeTab = 'hot'">推荐打手</view>
    </view>
    
    <!-- Banner管理 -->
    <view class="config-area" v-if="activeTab === 'banner'">
      <button class="add-btn" @click="showBannerDialog()">+ 添加Banner</button>
      <view class="list">
        <view class="list-item" v-for="(item, idx) in banners" :key="item.id">
          <image :src="item.image" class="preview-img" mode="aspectFill"></image>
          <view class="info">
            <text class="title">{{ item.title || '无标题' }}</text>
            <text class="sort">排序: {{ item.sort }}</text>
          </view>
          <view class="actions">
            <button class="delete" @click="deleteBanner(item.id)">删除</button>
          </view>
        </view>
      </view>
    </view>
    
    <!-- 菜单管理 -->
    <view class="config-area" v-if="activeTab === 'menu'">
      <button class="add-btn" @click="showMenuDialog()">+ 添加菜单</button>
      <view class="list">
        <view class="list-item" v-for="item in menus" :key="item.id">
          <image :src="item.icon" class="preview-icon" mode="aspectFit"></image>
          <view class="info">
            <text class="title">{{ item.name }}</text>
            <text class="link">链接: {{ item.link_url }}</text>
          </view>
          <view class="actions">
            <button class="edit" @click="showMenuDialog(item)">编辑</button>
            <button class="delete" @click="deleteMenu(item.id)">删除</button>
          </view>
        </view>
      </view>
    </view>
    
    <!-- 公告管理 -->
    <view class="config-area" v-if="activeTab === 'notice'">
      <button class="add-btn" @click="showNoticeDialog()">+ 添加公告</button>
      <view class="list">
        <view class="list-item" v-for="item in notices" :key="item.id">
          <view class="info">
            <text class="title">{{ item.title }}</text>
            <text class="content">{{ item.content }}</text>
          </view>
          <view class="actions">
            <button class="edit" @click="showNoticeDialog(item)">编辑</button>
            <button class="delete" @click="deleteNotice(item.id)">删除</button>
          </view>
        </view>
      </view>
    </view>
    
    <!-- 推荐打手管理 -->
    <view class="config-area" v-if="activeTab === 'hot'">
      <button class="add-btn" @click="showHotPlayerDialog()">+ 添加推荐打手</button>
      <view class="list">
        <view class="list-item" v-for="item in hotPlayers" :key="item.id">
          <view class="info">
            <text class="title">{{ item.nickname }}</text>
          </view>
          <view class="actions">
            <button class="delete" @click="deleteHotPlayer(item.id)">移除</button>
          </view>
        </view>
      </view>
    </view>
    
    <!-- 添加/编辑Banner弹窗 -->
    <uni-popup ref="bannerPopup" type="center">
      <view class="popup">
        <text class="popup-title">{{ bannerForm.id ? '编辑Banner' : '添加Banner' }}</text>
        <input class="input" v-model="bannerForm.title" placeholder="标题（选填）" />
        <input class="input" v-model="bannerForm.link_url" placeholder="跳转链接（选填）" />
        <view class="upload-area" @click="uploadBannerImage">
          <image v-if="bannerForm.image" :src="bannerForm.image" class="upload-preview"></image>
          <view v-else class="upload-placeholder">点击上传图片</view>
        </view>
        <view class="popup-buttons">
          <button class="cancel" @click="closeBannerDialog">取消</button>
          <button class="confirm" @click="saveBanner">保存</button>
        </view>
      </view>
    </uni-popup>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { 
  getAllBanners, addBanner, deleteBanner,
  getAllMenus, saveMenu, deleteMenu,
  getAllNotices, saveNotice, deleteNotice,
  getAllHotPlayers, addHotPlayer, deleteHotPlayer
} from '@/api/config';

const activeTab = ref('banner');
const banners = ref([]);
const menus = ref([]);
const notices = ref([]);
const hotPlayers = ref([]);

const bannerForm = ref({ id: null, title: '', link_url: '', image: '' });
const bannerImageFile = ref(null);

// 加载数据
const loadBanners = async () => {
  const res = await getAllBanners();
  if (res.code === 200) banners.value = res.data;
};

const loadMenus = async () => {
  const res = await getAllMenus();
  if (res.code === 200) menus.value = res.data;
};

const loadNotices = async () => {
  const res = await getAllNotices();
  if (res.code === 200) notices.value = res.data;
};

const loadHotPlayers = async () => {
  const res = await getAllHotPlayers();
  if (res.code === 200) hotPlayers.value = res.data.list;
};

// Banner操作
const showBannerDialog = (item = null) => {
  if (item) {
    bannerForm.value = { ...item };
  } else {
    bannerForm.value = { id: null, title: '', link_url: '', image: '' };
  }
  uni.$refs.bannerPopup.open();
};

const closeBannerDialog = () => {
  uni.$refs.bannerPopup.close();
};

const uploadBannerImage = () => {
  uni.chooseImage({
    count: 1,
    success: (res) => {
      bannerForm.value.image = res.tempFilePaths[0];
      bannerImageFile.value = res.tempFilePaths[0];
    }
  });
};

const saveBanner = async () => {
  if (!bannerImageFile.value && !bannerForm.value.id) {
    uni.showToast({ title: '请上传图片', icon: 'none' });
    return;
  }
  
  uni.showLoading({ title: '保存中...' });
  // 实际需要上传文件，这里简化
  uni.showToast({ title: '保存成功', icon: 'success' });
  closeBannerDialog();
  loadBanners();
  uni.hideLoading();
};

const deleteBannerItem = async (id) => {
  uni.showModal({
    title: '确认删除',
    content: '确定要删除这个Banner吗？',
    success: async (res) => {
      if (res.confirm) {
        await deleteBanner(id);
        loadBanners();
      }
    }
  });
};

// 其他类似方法...
</script>

<style lang="scss" scoped>
// 样式略...
</style><template>
  <view class="page">
    <view class="form-card">
      <view class="form-item">
        <text class="label">服务类型 <text class="required">*</text></text>
        <view class="type-select">
          <view 
            class="type-option" 
            :class="{ active: form.service_type === 1 }"
            @click="form.service_type = 1"
          >
            <text class="type-icon">🛡️</text>
            <text>护航</text>
          </view>
          <view 
            class="type-option" 
            :class="{ active: form.service_type === 2 }"
            @click="form.service_type = 2"
          >
            <text class="type-icon">🎮</text>
            <text>代练</text>
          </view>
          <view 
            class="type-option" 
            :class="{ active: form.service_type === 3 }"
            @click="form.service_type = 3"
          >
            <text class="type-icon">📖</text>
            <text>教学</text>
          </view>
        </view>
      </view>
      
      <view class="form-item">
        <text class="label">游戏地图</text>
        <picker mode="selector" :range="mapList" @change="onMapChange">
          <view class="picker-input">
            <text :class="{ placeholder: !form.game_map }">{{ form.game_map || '请选择地图' }}</text>
            <text class="arrow">›</text>
          </view>
        </picker>
      </view>
      
      <view class="form-item">
        <text class="label">订单金额 <text class="required">*</text></text>
        <view class="price-input">
          <text class="unit">¥</text>
          <input 
            type="digit" 
            v-model="form.price" 
            placeholder="请输入金额"
            class="input"
          />
        </view>
      </view>
      
      <view class="form-item">
        <text class="label">备注说明</text>
        <textarea 
          v-model="form.remark" 
          placeholder="请输入备注（选填）"
          maxlength="200"
          class="textarea"
        />
        <text class="count">{{ form.remark.length }}/200</text>
      </view>
      
      <view class="fee-info">
        <text>平台服务费：¥{{ platformFee }}</text>
        <text>打手实得：¥{{ playerIncome }}</text>
      </view>
      
      <button class="submit-btn" @click="submitOrder">确认发布</button>
    </view>
  </view>
</template>

<script setup>
import { ref, computed } from 'vue';
import { createOrder } from '@/api/order';

const form = ref({
  service_type: 1,
  game_map: '',
  price: '',
  remark: ''
});

const mapList = ['农场', '山谷', '北部山区', '电视台', '军港'];

const platformFee = computed(() => {
  const price = parseFloat(form.value.price) || 0;
  return (price * 0.1).toFixed(2);
});

const playerIncome = computed(() => {
  const price = parseFloat(form.value.price) || 0;
  return (price * 0.9).toFixed(2);
});

const onMapChange = (e) => {
  form.value.game_map = mapList[e.detail.value];
};

const submitOrder = async () => {
  if (!form.value.service_type) {
    uni.showToast({ title: '请选择服务类型', icon: 'none' });
    return;
  }
  if (!form.value.price || parseFloat(form.value.price) <= 0) {
    uni.showToast({ title: '请输入正确的金额', icon: 'none' });
    return;
  }
  
  uni.showLoading({ title: '发布中...' });
  try {
    const res = await createOrder({
      service_type: form.value.service_type,
      game_map: form.value.game_map,
      price: parseFloat(form.value.price),
      remark: form.value.remark
    });
    if (res.code === 200) {
      uni.showToast({ title: '发布成功', icon: 'success' });
      setTimeout(() => {
        uni.navigateBack();
      }, 1500);
    }
  } catch (e) {
    uni.showToast({ title: '发布失败', icon: 'error' });
  }
  uni.hideLoading();
};
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.form-card {
  background: white;
  border-radius: 24rpx;
  padding: 30rpx;
}

.form-item {
  margin-bottom: 40rpx;
  
  .label {
    font-size: 28rpx;
    font-weight: bold;
    display: block;
    margin-bottom: 16rpx;
    
    .required {
      color: #f44336;
    }
  }
  
  .type-select {
    display: flex;
    gap: 20rpx;
    
    .type-option {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24rpx;
      background: #f5f5f5;
      border-radius: 16rpx;
      border: 2rpx solid transparent;
      
      &.active {
        background: #FFF3E8;
        border-color: #FF6B35;
        
        .type-icon {
          color: #FF6B35;
        }
      }
      
      .type-icon {
        font-size: 48rpx;
        margin-bottom: 12rpx;
      }
    }
  }
  
  .picker-input {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 24rpx;
    background: #f5f5f5;
    border-radius: 16rpx;
    
    .placeholder {
      color: #999;
    }
    
    .arrow {
      font-size: 32rpx;
      color: #999;
    }
  }
  
  .price-input {
    display: flex;
    align-items: center;
    background: #f5f5f5;
    border-radius: 16rpx;
    padding: 0 24rpx;
    
    .unit {
      font-size: 32rpx;
      font-weight: bold;
      margin-right: 12rpx;
    }
    
    .input {
      flex: 1;
      padding: 24rpx 0;
    }
  }
  
  .textarea {
    background: #f5f5f5;
    border-radius: 16rpx;
    padding: 24rpx;
    height: 200rpx;
  }
  
  .count {
    font-size: 22rpx;
    color: #999;
    text-align: right;
    display: block;
    margin-top: 8rpx;
  }
}

.fee-info {
  background: #FFF9E8;
  padding: 24rpx;
  border-radius: 16rpx;
  margin-bottom: 40rpx;
  display: flex;
  justify-content: space-between;
  font-size: 26rpx;
  color: #666;
}

.submit-btn {
  background: #FF6B35;
  color: white;
  border: none;
  border-radius: 50rpx;
  padding: 28rpx;
  font-size: 32rpx;
}
</style><template>
  <view class="page">
    <view class="tabs">
      <view 
        class="tab" 
        :class="{ active: activeTab === 0 }" 
        @click="activeTab = 0; loadOrders()"
      >全部</view>
      <view 
        class="tab" 
        :class="{ active: activeTab === 0 }" 
        @click="activeTab = 0; loadOrders()"
      >待接单</view>
      <view 
        class="tab" 
        :class="{ active: activeTab === 1 }" 
        @click="activeTab = 1; loadOrders()"
      >进行中</view>
      <view 
        class="tab" 
        :class="{ active: activeTab === 2 }" 
        @click="activeTab = 2; loadOrders()"
      >已完成</view>
    </view>
    
    <view class="order-list">
      <view class="order-card" v-for="order in orders" :key="order.id" @click="goDetail(order.id)">
        <view class="order-header">
          <text class="order-sn">订单号：{{ order.order_sn }}</text>
          <view class="status" :class="getStatusClass(order.status)">
            {{ getStatusText(order.status) }}
          </view>
        </view>
        <view class="order-info">
          <text>{{ getServiceType(order.service_type) }}</text>
          <text>{{ order.game_map || '未知地图' }}</text>
          <text class="price">¥{{ order.price }}</text>
        </view>
        <view class="order-time">
          <text>{{ order.create_time }}</text>
        </view>
      </view>
      
      <view class="empty" v-if="orders.length === 0">
        <text>暂无订单</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getMyOrders } from '@/api/order';

const activeTab = ref(0);
const orders = ref([]);

const getServiceType = (type) => {
  const map = { 1: '护航', 2: '代练', 3: '教学' };
  return map[type] || '未知';
};

const getStatusText = (status) => {
  const map = { 0: '待接单', 1: '进行中', 2: '已完成', 3: '已取消', 4: '存单中' };
  return map[status] || '未知';
};

const getStatusClass = (status) => {
  if (status === 0) return 'pending';
  if (status === 1) return 'processing';
  if (status === 2) return 'completed';
  return 'other';
};

const loadOrders = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getMyOrders();
    if (res.code === 200) {
      orders.value = res.data;
    }
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const goDetail = (id) => {
  uni.navigateTo({ url: `/pages/order/detail?id=${id}` });
};

onShow(() => {
  loadOrders();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.tabs {
  display: flex;
  background: white;
  border-radius: 50rpx;
  margin-bottom: 30rpx;
  
  .tab {
    flex: 1;
    text-align: center;
    padding: 20rpx;
    font-size: 28rpx;
    color: #666;
    
    &.active {
      background: #FF6B35;
      color: white;
      border-radius: 50rpx;
    }
  }
}

.order-list {
  .order-card {
    background: white;
    border-radius: 20rpx;
    padding: 24rpx;
    margin-bottom: 20rpx;
    
    .order-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16rpx;
      
      .order-sn {
        font-size: 24rpx;
        color: #999;
      }
      
      .status {
        padding: 6rpx 20rpx;
        border-radius: 30rpx;
        font-size: 22rpx;
        
        &.pending { background: #FF9800; color: white; }
        &.processing { background: #2196F3; color: white; }
        &.completed { background: #4CAF50; color: white; }
        &.other { background: #999; color: white; }
      }
    }
    
    .order-info {
      display: flex;
      gap: 24rpx;
      margin-bottom: 16rpx;
      font-size: 28rpx;
      
      .price {
        color: #FF6B35;
        font-weight: bold;
        margin-left: auto;
      }
    }
    
    .order-time {
      font-size: 22rpx;
      color: #999;
    }
  }
}

.empty {
  text-align: center;
  padding: 100rpx;
  color: #999;
}
</style><template>
  <view class="page">
    <view class="order-card" v-if="order">
      <view class="status-bar" :class="getStatusClass(order.status)">
        <text>{{ getStatusText(order.status) }}</text>
      </view>
      
      <view class="info-section">
        <text class="section-title">订单信息</text>
        <view class="info-row">
          <text class="label">订单号</text>
          <text class="value">{{ order.order_sn }}</text>
        </view>
        <view class="info-row">
          <text class="label">服务类型</text>
          <text class="value">{{ getServiceType(order.service_type) }}</text>
        </view>
        <view class="info-row">
          <text class="label">游戏地图</text>
          <text class="value">{{ order.game_map || '未指定' }}</text>
        </view>
        <view class="info-row">
          <text class="label">订单金额</text>
          <text class="value price">¥{{ order.price }}</text>
        </view>
        <view class="info-row">
          <text class="label">平台服务费</text>
          <text class="value">¥{{ order.platform_fee }}</text>
        </view>
        <view class="info-row">
          <text class="label">打手收入</text>
          <text class="value">¥{{ order.player_income }}</text>
        </view>
        <view class="info-row" v-if="order.remark">
          <text class="label">备注</text>
          <text class="value">{{ order.remark }}</text>
        </view>
      </view>
      
      <view class="info-section" v-if="order.player_id">
        <text class="section-title">打手信息</text>
        <view class="info-row">
          <text class="label">打手昵称</text>
          <text class="value">{{ order.player_nickname }}</text>
        </view>
      </view>
      
      <view class="action-buttons" v-if="canAction">
        <button v-if="order.status === 1 && isPlayer" class="action-btn save" @click="doSave">暂存订单</button>
        <button v-if="order.status === 1 && isPlayer" class="action-btn cancel" @click="doCancel">退单</button>
        <button v-if="order.status === 1 && isPlayer" class="action-btn complete" @click="doComplete">完成订单</button>
        <button v-if="order.status === 0 && isPlayer" class="action-btn grab" @click="doGrab">立即接单</button>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, computed, onLoad } from 'vue';
import { getOrderDetail, grabOrder, cancelOrder, saveOrder, completeOrder } from '@/api/order';
import { getUserInfo } from '@/api/user';

const order = ref(null);
const currentUser = ref(null);
const orderId = ref('');

const isPlayer = computed(() => {
  return currentUser.value && (currentUser.value.level === 1 || currentUser.value.level === 3);
});

const canAction = computed(() => {
  if (!order.value) return false;
  // 打手可以操作进行中的订单
  if (isPlayer.value && order.value.status === 1) return true;
  // 打手可以接待接单的订单
  if (isPlayer.value && order.value.status === 0) return true;
  return false;
});

const getServiceType = (type) => {
  const map = { 1: '护航', 2: '代练', 3: '教学' };
  return map[type] || '未知';
};

const getStatusText = (status) => {
  const map = { 0: '待接单', 1: '进行中', 2: '已完成', 3: '已取消', 4: '存单中' };
  return map[status] || '未知';
};

const getStatusClass = (status) => {
  if (status === 0) return 'pending';
  if (status === 1) return 'processing';
  if (status === 2) return 'completed';
  return 'other';
};

const loadData = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const [orderRes, userRes] = await Promise.all([
      getOrderDetail(orderId.value),
      getUserInfo()
    ]);
    if (orderRes.code === 200) order.value = orderRes.data;
    if (userRes.code === 200) currentUser.value = userRes.data;
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const doGrab = async () => {
  uni.showModal({
    title: '确认接单',
    content: '确定要接这个订单吗？',
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '接单中...' });
        const result = await grabOrder(order.value.id);
        if (result.code === 200) {
          uni.showToast({ title: result.msg, icon: 'success' });
          loadData();
        }
        uni.hideLoading();
      }
    }
  });
};

const doSave = async () => {
  uni.showLoading({ title: '暂存中...' });
  const result = await saveOrder(order.value.id);
  if (result.code === 200) {
    uni.showToast({ title: result.msg, icon: 'success' });
    loadData();
  }
  uni.hideLoading();
};

const doCancel = async () => {
  uni.showModal({
    title: '确认退单',
    content: '确定要退单吗？',
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '退单中...' });
        const result = await cancelOrder(order.value.id, '打手退单');
        if (result.code === 200) {
          uni.showToast({ title: result.msg, icon: 'success' });
          loadData();
        }
        uni.hideLoading();
      }
    }
  });
};

const doComplete = async () => {
  uni.showModal({
    title: '确认完成',
    content: '确定已完成该订单吗？',
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '处理中...' });
        const result = await completeOrder(order.value.id);
        if (result.code === 200) {
          uni.showToast({ title: result.msg, icon: 'success' });
          loadData();
        }
        uni.hideLoading();
      }
    }
  });
};

onLoad((options) => {
  orderId.value = options.id;
  loadData();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.order-card {
  background: white;
  border-radius: 24rpx;
  overflow: hidden;
}

.status-bar {
  padding: 24rpx;
  text-align: center;
  color: white;
  
  &.pending { background: #FF9800; }
  &.processing { background: #2196F3; }
  &.completed { background: #4CAF50; }
  &.other { background: #999; }
}

.info-section {
  padding: 24rpx;
  border-bottom: 1rpx solid #f0f0f0;
  
  .section-title {
    font-size: 30rpx;
    font-weight: bold;
    display: block;
    margin-bottom: 20rpx;
  }
  
  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 16rpx 0;
    
    .label {
      font-size: 28rpx;
      color: #666;
    }
    
    .value {
      font-size: 28rpx;
      
      &.price {
        color: #FF6B35;
        font-weight: bold;
      }
    }
  }
}

.action-buttons {
  display: flex;
  gap: 20rpx;
  padding: 24rpx;
  
  .action-btn {
    flex: 1;
    padding: 24rpx;
    border-radius: 50rpx;
    font-size: 28rpx;
    
    &.grab, &.complete {
      background: #FF6B35;
      color: white;
    }
    
    &.save {
      background: #2196F3;
      color: white;
    }
    
    &.cancel {
      background: #f5f5f5;
      color: #666;
    }
  }
}
</style><template>
  <view class="page">
    <view class="tabs">
      <view class="tab" :class="{ active: rankType === 'day' }" @click="rankType = 'day'; loadRank()">日榜</view>
      <view class="tab" :class="{ active: rankType === 'week' }" @click="rankType = 'week'; loadRank()">周榜</view>
      <view class="tab" :class="{ active: rankType === 'total' }" @click="rankType = 'total'; loadRank()">总榜</view>
    </view>
    
    <view class="rank-list">
      <view class="rank-item" v-for="(player, idx) in rankList" :key="player.id">
        <view class="rank-num" :class="{ top: idx < 3 }">{{ idx + 1 }}</view>
        <image class="avatar" :src="player.avatar || '/static/default-avatar.png'" mode="aspectFill"></image>
        <view class="info">
          <text class="nickname">{{ player.nickname }}</text>
          <text class="orders">接单 {{ player.total_orders || 0 }} 单</text>
        </view>
        <view class="income">
          <text class="label">收入</text>
          <text class="amount">¥{{ player.total_earned || 0 }}</text>
        </view>
      </view>
      
      <view class="empty" v-if="rankList.length === 0">
        <text>暂无数据</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getPlayerRank } from '@/api/player';

const rankType = ref('total');
const rankList = ref([]);

const loadRank = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getPlayerRank(rankType.value);
    if (res.code === 200) {
      rankList.value = res.data;
    }
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

onShow(() => {
  loadRank();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.tabs {
  display: flex;
  background: white;
  border-radius: 50rpx;
  margin-bottom: 30rpx;
  
  .tab {
    flex: 1;
    text-align: center;
    padding: 20rpx;
    font-size: 28rpx;
    color: #666;
    
    &.active {
      background: #FF6B35;
      color: white;
      border-radius: 50rpx;
    }
  }
}

.rank-list {
  background: white;
  border-radius: 24rpx;
  overflow: hidden;
  
  .rank-item {
    display: flex;
    align-items: center;
    padding: 20rpx 24rpx;
    border-bottom: 1rpx solid #f0f0f0;
    
    .rank-num {
      width: 60rpx;
      font-size: 32rpx;
      font-weight: bold;
      color: #999;
      
      &.top {
        color: #FFD700;
      }
    }
    
    .avatar {
      width: 80rpx;
      height: 80rpx;
      border-radius: 50%;
      margin-right: 20rpx;
    }
    
    .info {
      flex: 1;
      
      .nickname {
        font-size: 30rpx;
        font-weight: bold;
        display: block;
      }
      
      .orders {
        font-size: 24rpx;
        color: #999;
      }
    }
    
    .income {
      text-align: right;
      
      .label {
        font-size: 22rpx;
        color: #999;
        display: block;
      }
      
      .amount {
        font-size: 28rpx;
        font-weight: bold;
        color: #FF6B35;
      }
    }
  }
}

.empty {
  text-align: center;
  padding: 100rpx;
  color: #999;
}
</style><template>
  <view class="page">
    <view class="tabs">
      <view class="tab" :class="{ active: activeTab === 0 }" @click="activeTab = 0; loadOrders()">进行中</view>
      <view class="tab" :class="{ active: activeTab === 1 }" @click="activeTab = 1; loadOrders()">存单中</view>
      <view class="tab" :class="{ active: activeTab === 2 }" @click="activeTab = 2; loadOrders()">已完成</view>
    </view>
    
    <view class="order-list">
      <view class="order-card" v-for="order in orders" :key="order.id" @click="goDetail(order.id)">
        <view class="order-header">
          <text class="boss">老板：{{ order.boss_nickname || '未知' }}</text>
          <view class="status" :class="getStatusClass(order.status)">
            {{ getStatusText(order.status) }}
          </view>
        </view>
        <view class="order-info">
          <text>{{ getServiceType(order.service_type) }}</text>
          <text>{{ order.game_map || '未知地图' }}</text>
          <text class="price">¥{{ order.player_income }}</text>
        </view>
        <view class="order-time">
          <text>{{ order.create_time }}</text>
        </view>
      </view>
      
      <view class="empty" v-if="orders.length === 0">
        <text>暂无订单</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getMyGrabOrders } from '@/api/order';

const activeTab = ref(0);
const orders = ref([]);

const getServiceType = (type) => {
  const map = { 1: '护航', 2: '代练', 3: '教学' };
  return map[type] || '未知';
};

const getStatusText = (status) => {
  const map = { 1: '进行中', 4: '存单中', 2: '已完成' };
  return map[status] || '未知';
};

const getStatusClass = (status) => {
  if (status === 1) return 'processing';
  if (status === 4) return 'saved';
  if (status === 2) return 'completed';
  return 'other';
};

const loadOrders = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const res = await getMyGrabOrders();
    if (res.code === 200) {
      let statusFilter = [];
      if (activeTab.value === 0) statusFilter = [1];
      else if (activeTab.value === 1) statusFilter = [4];
      else if (activeTab.value === 2) statusFilter = [2];
      orders.value = res.data.filter(o => statusFilter.includes(o.status));
    }
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const goDetail = (id) => {
  uni.navigateTo({ url: `/pages/order/detail?id=${id}` });
};

onShow(() => {
  loadOrders();
});
</script>

<style lang="scss" scoped>
// 样式同订单列表页
</style><template>
  <view class="page">
    <view class="club-list">
      <view class="club-card" v-for="club in clubs" :key="club.id" @click="goDetail(club.id)">
        <image class="logo" :src="club.logo || '/static/club-default.png'" mode="aspectFill"></image>
        <view class="info">
          <text class="name">{{ club.name }}</text>
          <text class="desc">{{ club.description || '暂无简介' }}</text>
          <text class="member">👥 {{ club.member_count || 0 }} 人加入</text>
        </view>
        <button class="join-btn" v-if="!myClubId || myClubId !== club.id" @click.stop="joinClub(club.id)">加入</button>
        <view class="joined-tag" v-else>已加入</view>
      </view>
      
      <view class="empty" v-if="clubs.length === 0">
        <text>暂无俱乐部</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getClubList, joinClub, getMyClub } from '@/api/club';

const clubs = ref([]);
const myClubId = ref(null);

const loadClubs = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const [listRes, myRes] = await Promise.all([
      getClubList(),
      getMyClub()
    ]);
    if (listRes.code === 200) clubs.value = listRes.data;
    if (myRes.code === 200 && myRes.data) myClubId.value = myRes.data.id;
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const joinClub = async (clubId) => {
  uni.showModal({
    title: '确认加入',
    content: '确定要加入这个俱乐部吗？',
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '加入中...' });
        const result = await joinClub(clubId);
        if (result.code === 200) {
          uni.showToast({ title: result.msg, icon: 'success' });
          loadClubs();
        }
        uni.hideLoading();
      }
    }
  });
};

const goDetail = (id) => {
  uni.navigateTo({ url: `/pages/club/detail?id=${id}` });
};

onShow(() => {
  loadClubs();
});
</script>

<style lang="scss" scoped>
.page {
  padding: 20rpx;
  padding-bottom: 100rpx;
}

.club-list {
  .club-card {
    background: white;
    border-radius: 20rpx;
    padding: 24rpx;
    margin-bottom: 20rpx;
    display: flex;
    align-items: center;
    
    .logo {
      width: 100rpx;
      height: 100rpx;
      border-radius: 20rpx;
      margin-right: 20rpx;
    }
    
    .info {
      flex: 1;
      
      .name {
        font-size: 30rpx;
        font-weight: bold;
        display: block;
        margin-bottom: 8rpx;
      }
      
      .desc {
        font-size: 24rpx;
        color: #666;
        display: block;
        margin-bottom: 8rpx;
      }
      
      .member {
        font-size: 22rpx;
        color: #999;
      }
    }
    
    .join-btn {
      background: #FF6B35;
      color: white;
      border: none;
      padding: 12rpx 32rpx;
      border-radius: 50rpx;
      font-size: 26rpx;
    }
    
    .joined-tag {
      background: #f0f0f0;
      padding: 12rpx 32rpx;
      border-radius: 50rpx;
      font-size: 26rpx;
      color: #999;
    }
  }
}

.empty {
  text-align: center;
  padding: 100rpx;
  color: #999;
}
</style><template>
  <view class="page" v-if="myClub">
    <view class="club-header">
      <image class="cover" :src="myClub.cover || '/static/club-cover.jpg'" mode="aspectFill"></image>
      <view class="info-overlay">
        <image class="logo" :src="myClub.logo || '/static/club-default.png'" mode="aspectFill"></image>
        <text class="name">{{ myClub.name }}</text>
        <text class="member-count">成员 {{ myClub.member_count }} 人</text>
      </view>
    </view>
    
    <view class="section">
      <view class="section-title">俱乐部简介</view>
      <text class="desc">{{ myClub.description || '暂无简介' }}</text>
    </view>
    
    <view class="section">
      <view class="section-title">成员列表</view>
      <view class="member-list">
        <view class="member-item" v-for="member in members" :key="member.id">
          <image class="avatar" :src="member.avatar || '/static/default-avatar.png'" mode="aspectFill"></image>
          <text class="nickname">{{ member.nickname }}</text>
          <text class="role" v-if="member.level === 1">管理员</text>
        </view>
      </view>
    </view>
    
    <button class="quit-btn" @click="quitClub">退出俱乐部</button>
  </view>
  
  <view class="empty" v-else>
    <text class="icon">🏛️</text>
    <text class="msg">您还未加入任何俱乐部</text>
    <button class="go-btn" @click="goToClubList">去加入</button>
  </view>
</template>

<script setup>
import { ref, onShow } from 'vue';
import { getMyClub, getClubDetail, quitClub } from '@/api/club';

const myClub = ref(null);
const members = ref([]);

const loadData = async () => {
  uni.showLoading({ title: '加载中...' });
  try {
    const clubRes = await getMyClub();
    if (clubRes.code === 200 && clubRes.data) {
      myClub.value = clubRes.data;
      const detailRes = await getClubDetail(myClub.value.id);
      if (detailRes.code === 200) {
        members.value = detailRes.data.members || [];
        myClub.value.member_count = detailRes.data.member_count;
      }
    }
  } catch (e) {
    console.error(e);
  }
  uni.hideLoading();
};

const quitClub = async () => {
  uni.showModal({
    title: '确认退出',
    content: '确定要退出该俱乐部吗？',
    success: async (res) => {
      if (res.confirm) {
        uni.showLoading({ title: '退出中...' });
        const result = await quitClub(myClub.value.id);
        if (result.code === 200) {
          uni.showToast({ title: result.msg, icon: 'success' });
          myClub.value = null;
        }
        uni.hideLoading();
      }
    }
  });
};

const goToClubList = () => {
  uni.navigateTo({ url: '/pages/club/list' });
};

onShow(() => {
  loadData();
});
</script>

<style lang="scss" scoped>
.page {
  padding-bottom: 100rpx;
}

.club-header {
  position: relative;
  height: 400rpx;
  
  .cover {
    width: 100%;
    height: 100%;
  }
  
  .info-overlay {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    background: linear-gradient(transparent, rgba(0,0,0,0.7));
    padding: 30rpx;
    display: flex;
    align-items: center;
    
    .logo {
      width: 100rpx;
      height: 100rpx;
      border-radius: 20rpx;
      margin-right: 20rpx;
      border: 2rpx solid white;
    }
    
    .name {
      flex: 1;
      font-size: 32rpx;
      font-weight: bold;
      color: white;
    }
    
    .member-count {
      font-size: 24rpx;
      color: rgba(255,255,255,0.8);
    }
  }
}

.section {
  background: white;
  margin: 20rpx;
  border-radius: 20rpx;
  padding: 24rpx;
  
  .section-title {
    font-size: 30rpx;
    font-weight: bold;
    margin-bottom: 16rpx;
  }
  
  .desc {
    font-size: 26rpx;
    color: #666;
    line-height: 1.6;
  }
}

.member-list {
  display: flex;
  flex-wrap: wrap;
  gap: 30rpx;
  
  .member-item {
    width: 120rpx;
    text-align: center;
    
    .avatar {
      width: 80rpx;
      height: 80rpx;
      border-radius: 50%;
      margin-bottom: 8rpx;
    }
    
    .nickname {
      font-size: 24rpx;
      display: block;
    }
    
    .role {
      font-size: 20rpx;
      color: #FF6B35;
    }
  }
}

.quit-btn {
  margin: 30rpx;
  background: #f5f5f5;
  color: #f44336;
  border: none;
  border-radius: 50rpx;
  padding: 24rpx;
}

.empty {
  text-align: center;
  padding: 150rpx 60rpx;
  
  .icon {
    font-size: 100rpx;
    display: block;
    margin-bottom: 30rpx;
  }
  
  .msg {
    font-size: 28rpx;
    color: #999;
    display: block;
    margin-bottom: 40rpx;
  }
  
  .go-btn {
    background: #FF6B35;
    color: white;
    border: none;
    border-radius: 50rpx;
    padding: 20rpx 60rpx;
    width: auto;
  }
}
</style>// api/player.js
import request from './request';

// 获取打手排行榜
export const getPlayerRank = (type) => {
  return request({
    url: '/player/rank',
    method: 'GET',
    data: { type }
  });
};// api/club.js
import request from './request';

// 获取俱乐部列表
export const getClubList = () => {
  return request({
    url: '/club/list',
    method: 'GET'
  });
};

// 获取俱乐部详情
export const getClubDetail = (clubId) => {
  return request({
    url: '/club/detail',
    method: 'GET',
    data: { club_id: clubId }
  });
};

// 加入俱乐部
export const joinClub = (clubId) => {
  return request({
    url: '/club/join',
    method: 'POST',
    data: { club_id: clubId }
  });
};

// 退出俱乐部
export const quitClub = (clubId) => {
  return request({
    url: '/club/quit',
    method: 'POST',
    data: { club_id: clubId }
  });
};

// 获取我的俱乐部
export const getMyClub = () => {
  return request({
    url: '/club/my',
    method: 'GET'
  });
};{
  "pages": [
    // ... 之前的页面
    {
      "path": "pages/order/create",
      "style": { "navigationBarTitleText": "发布订单" }
    },
    {
      "path": "pages/order/list",
      "style": { "navigationBarTitleText": "我的订单" }
    },
    {
      "path": "pages/order/detail",
      "style": { "navigationBarTitleText": "订单详情" }
    },
    {
      "path": "pages/player/rank",
      "style": { "navigationBarTitleText": "打手排行榜" }
    },
    {
      "path": "pages/player/orders",
      "style": { "navigationBarTitleText": "我接的订单" }
    },
    {
      "path": "pages/club/list",
      "style": { "navigationBarTitleText": "俱乐部列表" }
    },
    {
      "path": "pages/club/my",
      "style": { "navigationBarTitleText": "我的俱乐部" }
    },
    {
      "path": "pages/club/detail",
      "style": { "navigationBarTitleText": "俱乐部详情" }
    },
    {
      "path": "pages/withdraw/record",
      "style": { "navigationBarTitleText": "提现记录" }
    }
  ]
}-- =============================================
-- txy电竞 完整数据库（五级身份+打手等级系统）
-- =============================================

DROP DATABASE IF EXISTS `txy_electronic`;
CREATE DATABASE `txy_electronic` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `txy_electronic`;

-- =============================================
-- 1. 用户表（五级身份）
-- =============================================
DROP TABLE IF EXISTS `txy_user`;
CREATE TABLE `txy_user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `openid` varchar(100) DEFAULT NULL,
  `login_type` enum('wechat','qq','guest') DEFAULT 'guest',
  `nickname` varchar(50) NOT NULL DEFAULT '游客',
  `avatar` varchar(500) DEFAULT NULL,
  `level` tinyint(1) NOT NULL DEFAULT 5 COMMENT '1管理员 2成员 3打手 4老板 5游客',
  `player_rank` enum('gold','silver','bronze') DEFAULT 'bronze' COMMENT '打手等级',
  `is_certified` tinyint(1) DEFAULT 0 COMMENT '是否经管理员认证',
  `balance` decimal(10,2) DEFAULT 0.00,
  `points` int(11) DEFAULT 0,
  `total_orders` int(11) DEFAULT 0 COMMENT '总接单数',
  `total_earned` decimal(10,2) DEFAULT 0.00 COMMENT '总收入',
  `today_extra` decimal(10,2) DEFAULT 0.00 COMMENT '银牌每日加额',
  `status` tinyint(1) DEFAULT 1,
  `ban_reason` varchar(200) DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_openid` (`openid`),
  KEY `idx_level` (`level`),
  KEY `idx_player_rank` (`player_rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 插入默认管理员 (密码解锁后自动成为管理员，不需要预设)

-- =============================================
-- 2. 订单表
-- =============================================
DROP TABLE IF EXISTS `txy_order`;
CREATE TABLE `txy_order` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_sn` varchar(32) NOT NULL,
  `user_id` int(11) NOT NULL COMMENT '老板ID',
  `player_id` int(11) DEFAULT NULL COMMENT '接单打手ID',
  `service_type` tinyint(1) NOT NULL COMMENT '1:护航 2:代练 3:教学',
  `game_map` varchar(50) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL COMMENT '订单金额',
  `platform_fee` decimal(10,2) DEFAULT 0.00 COMMENT '平台抽成',
  `player_income` decimal(10,2) DEFAULT 0.00 COMMENT '打手实得',
  `player_rank_at_grab` enum('gold','silver','bronze') DEFAULT NULL COMMENT '接单时打手等级',
  `status` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0待接单 1进行中 2已完成 3已取消 4存单中',
  `remark` varchar(500) DEFAULT NULL,
  `expire_time` datetime DEFAULT NULL COMMENT '5分钟过期时间',
  `start_time` datetime DEFAULT NULL,
  `complete_time` datetime DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_order_sn` (`order_sn`),
  KEY `idx_status` (`status`),
  KEY `idx_expire_time` (`expire_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

-- =============================================
-- 3. 组队申请表（打手接单后申请组队）
-- =============================================
DROP TABLE IF EXISTS `txy_team_apply`;
CREATE TABLE `txy_team_apply` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `player_id` int(11) NOT NULL COMMENT '发起组队的打手',
  `target_player_id` int(11) DEFAULT NULL COMMENT '目标打手（可为空，表示寻找所有打手）',
  `status` tinyint(1) DEFAULT 0 COMMENT '0待处理 1已接受 2已拒绝',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='组队申请表';

-- =============================================
-- 4. 打手等级变更记录
-- =============================================
DROP TABLE IF EXISTS `txy_player_rank_log`;
CREATE TABLE `txy_player_rank_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `old_rank` enum('gold','silver','bronze') DEFAULT NULL,
  `new_rank` enum('gold','silver','bronze') NOT NULL,
  `operator_id` int(11) NOT NULL COMMENT '操作人(管理员)',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='打手等级变更记录';

-- =============================================
-- 5. 提现申请表
-- =============================================
DROP TABLE IF EXISTS `txy_withdraw`;
CREATE TABLE `txy_withdraw` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `image_url` varchar(500) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0待处理 1已打款 2拒绝',
  `apply_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `process_time` datetime DEFAULT NULL,
  `processor_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='提现申请表';

-- =============================================
-- 6. 每日银牌加额记录
-- =============================================
DROP TABLE IF EXISTS `txy_daily_extra`;
CREATE TABLE `txy_daily_extra` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `amount` decimal(10,2) DEFAULT 0.50,
  `is_paid` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_date` (`user_id`, `date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日银牌加额记录';

-- =============================================
-- 7. 其他表（私信、处罚、俱乐部等保持之前的设计）
-- =============================================
-- ... (省略，与之前相同)<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use app\model\Order as OrderModel;
use think\facade\Db;
use think\facade\Cache;

class Order extends BaseController
{
    // 抽成配置
    private $feeConfig = [
        'gold' => 0.5,    // 金牌抽成0.5元
        'silver' => 1.0,  // 银牌抽成1元
        'bronze' => 2.0   // 铜牌抽成2元
    ];
    
    // 银牌每日加额
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
    
    // 发布订单
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
            'expire_time' => date('Y-m-d H:i:s', strtotime('+5 minutes')), // 5分钟过期
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        // 扣减老板余额
        $user->balance -= $data['price'];
        $user->save();
        
        return json(['code' => 200, 'data' => $order, 'msg' => '下单成功，5分钟无人接单将自动流入大厅']);
    }
    
    // 获取可接单列表（包含过期订单自动流转）
    public function getAvailableOrders()
    {
        // 将过期的订单状态改为已过期（或保留在待接单但前端过滤）
        $expiredOrders = OrderModel::where('status', 0)
            ->where('expire_time', '<', date('Y-m-d H:i:s'))
            ->select();
        
        foreach ($expiredOrders as $order) {
            // 过期订单仍然在待接单，但前端会显示"已流入大厅"
            // 或者可以修改状态
        }
        
        $orders = OrderModel::where('status', 0)
            ->order('create_time', 'asc')
            ->select();
            
        foreach ($orders as &$order) {
            $order['is_expired'] = strtotime($order['expire_time']) < time();
        }
        
        return json(['code' => 200, 'data' => $orders]);
    }
    
    // 打手接单（含抽成计算）
    public function grab()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        // 游客需要滑动验证（前端验证后传递token）
        if ($user->level == 5) {
            $captchaToken = $this->request->post('captcha_token');
            if (!$this->verifySlideCaptcha($captchaToken)) {
                return json(['code' => 400, 'msg' => '请完成滑动验证']);
            }
        }
        
        // 只有打手(3级)和管理员(1级)可以接单
        if (!in_array($user->level, [1,3])) {
            return json(['code' => 403, 'msg' => '您不是打手，无法接单']);
        }
        
        $orderId = $this->request->post('order_id');
        
        $order = OrderModel::where('id', $orderId)->lock(true)->find();
        
        if (!$order || $order->status != 0) {
            return json(['code' => 400, 'msg' => '订单不存在或已被抢']);
        }
        
        // 计算抽成和打手收入
        $playerRank = $user->player_rank;
        $fee = $this->feeConfig[$playerRank];
        $playerIncome = $order->price - $fee;
        
        // 银牌每日加额（记录到今日加额）
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
        
        // 记录日志
        Db::name('order_log')->insert([
            'order_id' => $orderId,
            'action' => '接单',
            'user_id' => $user->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '接单成功', 'data' => ['fee' => $fee, 'income' => $playerIncome]]);
    }
    
    // 完成订单（发放收入）
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
        
        // 发放收入
        $user->balance += $order->player_income;
        $user->total_orders += 1;
        $user->total_earned += $order->player_income;
        $user->save();
        
        // 银牌每日加额单独记录，晚上结算
        if ($user->player_rank == 'silver') {
            $this->recordDailyExtra($user->id);
        }
        
        return json(['code' => 200, 'msg' => '订单完成，收入已入账']);
    }
    
    // 退单
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
        
        // 退还老板余额
        $boss = UserModel::find($order->user_id);
        $boss->balance += $order->price;
        $boss->save();
        
        return json(['code' => 200, 'msg' => '退单成功']);
    }
    
    // 存单
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
    
    // 申请组队（接单完成后）
    public function applyTeam()
    {
        $user = $this->getUser();
        $orderId = $this->request->post('order_id');
        $targetPlayerId = $this->request->post('target_player_id'); // 可选，为空则查找所有打手
        
        $order = OrderModel::find($orderId);
        if (!$order || $order->player_id != $user->id || $order->status != 2) {
            return json(['code' => 400, 'msg' => '只有已完成订单的打手可以申请组队']);
  <?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Admin extends BaseController
{
    // 添加金牌打手（必须是银牌）
    public function addGoldPlayer()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
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
        
        // 记录日志
        Db::name('player_rank_log')->insert([
            'user_id' => $userId,
            'old_rank' => $oldRank,
            'new_rank' => 'gold',
            'operator_id' => $admin->id,
            'create_time' => date('Y-m-d H:i:s')
        ]);
        
        return json(['code' => 200, 'msg' => '已升级为金牌打手']);
    }
    
    // 添加银牌打手（必须是铜牌）
    public function addSilverPlayer()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
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
    
    // 获取所有打手列表（按等级排序）
    public function getPlayerList()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $players = UserModel::where('level', 3)
            ->orderRaw("FIELD(player_rank, 'gold', 'silver', 'bronze')")
            ->field('id, nickname, player_rank, total_orders, total_earned, balance')
            ->select();
        
        return json(['code' => 200, 'data' => $players]);
    }
    
    // 获取提现申请列表（晚上8-9点处理）
    public function getWithdrawList()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $list = Db::name('withdraw')->alias('w')
            ->join('txy_user u', 'w.user_id = u.id')
            ->field('w.*, u.nickname, u.player_rank')
            ->where('w.status', 0)
            ->order('w.apply_time', 'asc')
            ->select();
        
        return json(['code' => 200, 'data' => $list]);
    }
    
    // 处理提现（晚上8-9点统一打款）
    public function processWithdraw()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $currentHour = date('H');
        if ($currentHour < 20 || $currentHour >= 21) {
            return json(['code' => 400, 'msg' => '提现处理时间仅限晚上8:00-9:00']);
        }
        
        $withdrawId = $this->request->post('withdraw_id');
        $action = $this->request->post('action');
        
        $withdraw = Db::name('withdraw')->find($withdrawId);
        if (!$withdraw || $withdraw['status'] != 0) {
            return json(['code' => 400, 'msg' => '提现申请不存在']);
        }
        
        if ($action == 'approve') {
            // 金牌打手：直接打款（已提前申请）
            // 银牌/铜牌：晚上统一处理
            Db::name('withdraw')->where('id', $withdrawId)->update([
                'status' => 1,
                'process_time' => date('Y-m-d H:i:s'),
                'processor_id' => $admin->id
            ]);
            
            // 扣减余额
            $user = UserModel::find($withdraw['user_id']);
            $user->balance -= $withdraw['amount'];
            $user->save();
            
            $msg = "提现成功，已打款 {$withdraw['amount']} 元";
        } else {
            Db::name('withdraw')->where('id', $withdrawId)->update([
                'status' => 2,
                'process_time' => date('Y-m-d H:i:s'),
                'processor_id' => $admin->id
            ]);
            $msg = "提现申请已拒绝";
        }
        
        return json(['code' => 200, 'msg' => $msg]);
    }
    
    // 银牌每日加额结算（晚上8点自动执行）
    public function settleDailyExtra()
    {
        $admin = $this->getUser();
        if ($admin->level != 1) {
            return json(['code' => 403, 'msg' => '无权限']);
        }
        
        $today = date('Y-m-d');
        $records = Db::name('daily_extra')
            ->where('date', $today)
            ->where('is_paid', 1)
            ->select();
        
        foreach ($records as $record) {
            $user = UserModel::find($record['user_id']);
            $user->balance += $record['amount'];
            $user->today_extra += $record['amount'];
            $user->save();
        }
        
        return json(['code' => 200, 'msg' => '今日加额已结算']);
    }
}<?php
namespace app\controller;

use app\BaseController;
use app\model\User as UserModel;
use think\facade\Db;
use think\facade\Cache;

class Withdraw extends BaseController
{
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
        
        // 金牌打手：全天可申请提现
        // 银牌/铜牌：需要在晚上8-9点前申请
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
    
    // 检查是否可以提现（金牌全天可申请）
    public function checkWithdrawTime()
    {
        $user = $this->getUser();
        if (!$user) {
            return json(['code' => 401, 'msg' => '请先登录']);
        }
        
        $canApply = false;
        $currentHour = date('H');
        
        if ($user->player_rank == 'gold') {
            $canApply = true;
        } else {
            $canApply = ($currentHour >= 8 && $currentHour < 20);
        }
        
        return json(['code' => 200, 'data' => [
            'can_apply' => $canApply,
            'player_rank' => $user->player_rank,
            'current_hour' => $currentHour
        ]]);
    }
}<!-- components/SlideCaptcha.vue -->
<template>
  <view class="captcha-container" v-if="show">
    <view class="captcha-mask" @click="close"></view>
    <view class="captcha-panel">
      <text class="title">滑动验证</text>
      <view class="slider-container">
        <view class="slider-bg" :style="{ width: sliderPercent + '%' }"></view>
        <view 
          class="slider-btn" 
          @touchstart="onTouchStart" 
          @touchmove="onTouchMove" 
          @touchend="onTouchEnd"
          :style="{ transform: 'translateX(' + sliderLeft + 'px)' }"
        >
          <text>→</text>
        </view>
      </view>
      <text class="hint">请按住滑块拖动到最右侧</text>
    </view>
  </view>
</template>

<script setup>
import { ref, defineProps, defineEmits } from 'vue';

const props = defineProps(['show']);
const emit = defineEmits(['success', 'close']);

const sliderPercent = ref(0);
const sliderLeft = ref(0);
let startX = 0;
let containerWidth = 0;

const onTouchStart = (e) => {
  startX = e.touches[0].clientX;
  const query = uni.createSelectorQuery().in(this);
  query.select('.slider-container').boundingClientRect(rect => {
    containerWidth = rect.width - 60; // 减去按钮宽度
  }).exec();
};

const onTouchMove = (e) => {
  const moveX = e.touches[0].clientX - startX;
  if (moveX < 0) return;
  let percent = (moveX / containerWidth) * 100;
  if (percent > 100) percent = 100;
  sliderPercent.value = percent;
  sliderLeft.value = moveX > containerWidth ? containerWidth : moveX;
};

const onTouchEnd = () => {
  if (sliderPercent.value >= 95) {
    // 验证成功
    emit('success');
    close();
  } else {
    // 重置
    sliderPercent.value = 0;
    sliderLeft.value = 0;
    uni.showToast({ title: '请完整拖动滑块', icon: 'none' });
  }
};

const close = () => {
  emit('close');
  sliderPercent.value = 0;
  sliderLeft.value = 0;
};
</script>

<style lang="scss" scoped>
.captcha-container {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.captcha-mask {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.6);
}

.captcha-panel {
  position: relative;
  background: white;
  border-radius: 24rpx;
  padding: 40rpx;
  width: 600rpx;
  
  .title {
    font-size: 34rpx;
    font-weight: bold;
    text-align: center;
    display: block;
    margin-bottom: 40rpx;
  }
  
  .slider-container {
    position: relative;
    height: 80rpx;
    background: #f0f0f0;
    border-radius: 80rpx;
    margin-bottom: 30rpx;
    
    .slider-bg {
      position: absolute;
      height: 100%;
      background: #4CAF50;
      border-radius: 80rpx;
      transition: width 0.1s;
    }
    
    .slider-btn {
      position: absolute;
      width: 80rpx;
      height: 80rpx;
      background: white;
      border-radius: 50%;
      box-shadow: 0 2rpx 10rpx rgba(0,0,0,0.1);
      display: flex;
      align-items: center;
      justify-content: center;
      left: 0;
      top: 0;
      transition: transform 0.05s;
    }
  }
  
  .hint {
    font-size: 24rpx;
    color: #999;
    text-align: center;
    display: block;
  }
}
</style＞