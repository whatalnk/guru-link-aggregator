<template>
  <div>
    <slot></slot>
    <button v-on:click="readJson">Show links</button>
    <div v-for="item in links" :key="item.id">
      <ul>
        <li>
          <a v-bind:href="item.url">{{ item.title }}</a>
        </li>
      </ul>
    </div>
  </div>
</template>

<script>
export default {
  name: "list-links",
  data() {
    return {
      links: [],
    };
  },
  props: ["date"],
  computed: {
    formatDate: function () {
      let x = this.date.split("-").join("");
      return x;
    },
  },
  methods: {
    readJson: function () {
      let url = process.env.BASE_URL + "data/" + this.formatDate + ".json";
      console.log(url);
      fetch(url)
        .then((response) => response.json())
        .then((data) => (this.links = data));
    },
  },
};
</script>