<?php
namespace app\model;

use think\Model;

class User extends Model
{
    protected $table = 'txy_user';
    protected $pk = 'id';
    protected $autoWriteTimestamp = true;
    protected $createTime = 'create_time';
    protected $updateTime = 'update_time';
    
    protected $type = [
        'id' => 'integer',
        'level' => 'integer',
        'balance' => 'float',
        'points' => 'integer',
        'total_orders' => 'integer',
        'total_earned' => 'float',
        'status' => 'integer'
    ];
}