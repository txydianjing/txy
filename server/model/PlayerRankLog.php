<?php
namespace app\model;

use think\Model;

class PlayerRankLog extends Model
{
    protected $table = 'txy_player_rank_log';
    protected $pk = 'id';
    protected $autoWriteTimestamp = true;
    protected $createTime = 'create_time';
    
    protected $type = [
        'id' => 'integer',
        'user_id' => 'integer',
        'operator_id' => 'integer'
    ];
}