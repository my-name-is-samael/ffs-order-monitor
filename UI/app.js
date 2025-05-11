let app = {
  setup() {
    let showDriveThru = localStorage.getItem("driveThruState");
    if (showDriveThru === undefined || showDriveThru === null) {
      showDriveThru = true;
    } else {
      showDriveThru = showDriveThru === "true";
    }

    let showOther = localStorage.getItem("otherState");
    if (showOther === undefined || showOther === null) {
      showOther = true;
    } else {
      showOther = showOther === "true";
    }

    return {
      showDriveThru: ref(showDriveThru),
      showOther: ref(showOther),
      fetchProcess: ref(),
      orders: ref([]),
      notifications: ref([]),
      showHistory: ref(false),
    };
  },
  methods: {
    toggle(drive) {
      if (drive) {
        this.showDriveThru = !this.showDriveThru;
        localStorage.setItem("driveThruState", this.showDriveThru);
      } else {
        this.showOther = !this.showOther;
        localStorage.setItem("otherState", this.showOther);
      }
    },
    updateOrders(newOrders) {
      this.orders = newOrders;
    },
    getOrders() {
      let res = [];
      this.orders.forEach((order) => {
        if (order.drive) {
          if (this.showDriveThru) {
            res.push(order);
          }
        } else {
          if (this.showOther) {
            res.push(order);
          }
        }
      });
      return res;
    },
  },
  mounted() {
    let fetchOrders = () => {
      if (!window.FILE_ERRORS) {
        window.FILE_ERRORS = {};
      }
      if (window.FILE_ERRORS.length > 0) {
        clearInterval(this.fetchProcess);
        return;
      }

      function upsertScript(id, file) {
        // remove previous
        let existant = document.querySelector(`script#${id}`);
        if (existant) {
          existant.remove();
        }

        // create orders script
        let script = document.createElement("script");
        script.id = id;
        script.src = file;
        script.innerHTML = `alert('${file} can't be found, please check your mod installation.'); window.FILE_ERRORS["${id}"] = true;`;
        document.body.appendChild(script);
      }

      upsertScript("get-orders", "orders_export.js");
      upsertScript("get-events", "events_export.js");

      setTimeout(() => {
        if (window.GET_ORDERS) {
          this.updateOrders(window.GET_ORDERS());
        }
        if (window.GET_EVENTS) {
          this.notifications = window.GET_EVENTS();
        }
      }, 20);
    };
    this.fetchProcess = setInterval(fetchOrders, 500);
    fetchOrders();
  },
  beforeDestroy() {
    clearInterval(this.fetchProcess);
  },
  template: `
        <HeaderCmp 
            :driveThruState="showDriveThru"
            :otherState="showOther"
            @toggle="toggle($event)"
            @open-history="showHistory = true"/>
        <OrdersCmp :orders="getOrders()" />
        <NotifCmp :notifications="notifications" />
        <HistoryCmp
          :show="showHistory"
          :notifications="notifications"
          @close="showHistory = false" />
    `,
};

const { createApp, ref } = Vue;
createApp(app)
  .component("CheckCmp", CheckCmp)
  .component("HeaderCmp", HeaderCmp)
  .component("ArticleCmp", ArticleCmp)
  .component("OrderCmp", OrderCmp)
  .component("OrdersCmp", OrdersCmp)
  .component("NotifCmp", NotifCmp)
  .component("HistoryCmp", HistoryCmp)
  .mount("#app");
