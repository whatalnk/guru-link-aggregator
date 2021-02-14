<template>
  <div id="app">
    <input
      v-model="date"
      type="date"
      value="2021-02-11"
      min="2021-02-11"
      required
      pattern="\d{4}-\d{2}-\d{2}"
    />
    <span class="validity"></span>
    <p>{{ date }} のリンク一覧</p>
    <list-links :date="date"> </list-links>
  </div>
</template>

<script>
import ListLinks from "./components/ListLinks.vue";

export default {
  name: "App",
  components: { ListLinks },
  data() {
    return {
      date: "2021-02-11",
    };
  },
};
</script>

<style>
</style>
