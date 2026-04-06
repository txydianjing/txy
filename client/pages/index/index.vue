<template>
  <view class="page">
    <view class="header">
      <text class="title">txy电竞</text>
      <text class="subtitle">暗区突围俱乐部</text>
    </view>
    
    <view class="menu-grid">
      <view class="menu-item" @click="goTo('/pages/order/create')">
        <text>📝</text>
        <text>发布订单</text>
      </view>
      <view class="menu-item" @click="goTo('/pages/player/grab')">
        <text>⚡</text>
        <text>抢单大厅</text>
      </view>
      <view class="menu-item" @click="goTo('/pages/club/list')">
        <text>🏛️</text>
        <text>俱乐部</text>
      </view>
      <view class="menu-item" @click="goTo('/pages/user/profile')">
        <text>👤</text>
        <text>我的</text>
      </view>
    </view>
    
    <view class="card">
      <text class="card-title">最新订单</text>
      <view class="order-item" v-for="order in orders" :key="order.id">
        <text>{{ order.map }}</text>
        <text>¥{{ order.price }}</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';

const orders = ref([
  { id: 1, map: '农场', price: 88 },
  { id: 2, map: '电视台', price: 128 }
]);

const goTo = (url) => {
  uni.navigateTo({ url });
};
</script>

<style scoped>
.page { padding: 20px; background: #f5f5f5; }
.header { text-align: center; margin-bottom: 30px; }
.title { font-size: 28px; font-weight: bold; color: #FF6B35; }
.subtitle { font-size: 14px; color: #999; }
.menu-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; background: white; padding: 20px; border-radius: 20px; margin-bottom: 20px; }
.menu-item { text-align: center; }
.menu-item text:first-child { font-size: 30px; display: block; }
.menu-item text:last-child { font-size: 12px; color: #666; }
.card { background: white; border-radius: 20px; padding: 16px; }
.card-title { font-weight: bold; margin-bottom: 12px; display: block; }
.order-item { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #eee; }
</style>