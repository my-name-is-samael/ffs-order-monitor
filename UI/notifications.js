const NOTIF_EVENTS = {
  ped_arrived: {
    getLabel: (notif) => "A customer is waiting",
    getType: (notif) => "info",
  },
  ped_order_validated: {
    getLabel: (notif) => `Table ${notif.table} is ready`,
    getType: (notif) => "info",
  },
  ped_served_well: {
    getLabel: (notif) => `Table ${notif.table} has been served`,
    getType: (notif) => "success",
  },
  ped_served_badly: {
    getLabel: (notif) => `Table ${notif.table} has been badly served`,
    getType: (notif) => "error",
  },
  ped_left: {
    getLabel: (notif) =>
      notif.table
        ? `The customer left table ${notif.table}`
        : "A waiting customer left",
    getType: (notif) => "error",
  },
  car_arrived: {
    getLabel: (notif) => "A car is waiting",
    getType: (notif) => "info",
  },
  car_order_validated: {
    getLabel: (notif) => `Drive-Tru ${notif.table - 99} is ready`,
    getType: (notif) => "info",
  },
  car_served_well: {
    getLabel: (notif) => `Drive-Thru ${notif.table - 99} has been served`,
    getType: (notif) => "success",
  },
  car_served_badly: {
    getLabel: (notif) => `Drive-Thru ${notif.table - 99} has been badly served`,
    getType: (notif) => "error",
  },
  car_left: {
    getLabel: (notif) =>
      notif.table ? `Drive-Thru ${notif.table - 99} has left` : "A waiting car left",
    getType: (notif) => "error",
  },
};

const NOTIF_SETTINGS = {
  timeout: 5000,
  fade: 1000,
};

const NotifCmp = {
  props: ["notifications"],
  setup() {
    return {
      saw: ref([]),
      latests: ref([]),
      init: ref(false),
    };
  },
  methods: {
    updateNotifs(newNotifs, oldNotifs) {
      if (this.init) {
        for (let i = newNotifs.length - 1; i >= 0; i--) {
          let notif = newNotifs[i];
          if (
            !oldNotifs.find(
              (n) =>
                n.time === notif.time &&
                n.event === notif.event &&
                n.table === notif.table
            )
          ) {
            let label = NOTIF_EVENTS[notif.event].getLabel(notif);
            this.latests.push({
              id: UUID(),
              label: label,
              type: NOTIF_EVENTS[notif.event].getType(notif),
              time: parseGameTime(notif.time),
              visible: false,
            });
            setTimeout(() => {
              let found = this.latests.find((el) => el.label === label);
              if (found) {
                found.visible = true;
              }
            }, 1);
            setTimeout(() => {
              let found = this.latests.find((el) => el.label === label);
              if (found) {
                found.visible = false;
              }
            }, NOTIF_SETTINGS.timeout - NOTIF_SETTINGS.fade);
            setTimeout(() => {
              this.latests = this.latests.filter((el) => el.label !== label);
            }, NOTIF_SETTINGS.timeout);
          }
        }
      }
      this.saw = newNotifs;
    },
  },
  computed: {
    transitionLine: () =>
      `opacity ${NOTIF_SETTINGS.fade}ms ease-in-out, height ${NOTIF_SETTINGS.fade}ms ease-in-out`,
  },
  watch: {
    notifications: function (a, b) {
      this.updateNotifs(a, b);
    },
  },
  mounted() {
    setTimeout(() => {
      this.init = true;
    }, 100);
  },
  template: `
    <div class="notifs">
        <div class="notif"
            :style="{transition: transitionLine}"
            v-for="notif in latests"
            :key="notif.id"
            :class="notif.type + (notif.visible?' visible' : '')">
            <span class="time">{{notif.time}}</span>
            <span class="label">: {{notif.label}}</span>
        </div>
    </div>
  `,
};
