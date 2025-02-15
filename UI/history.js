const HistoryCmp = {
  props: ["show", "notifications"],
  methods: {
    formatTime(time) {
      return parseGameTime(time);
    },
    getNotifs() {
      return this.notifications.map((n) => ({
        type: n.type,
        time: this.formatTime(n.time),
        label: NOTIF_EVENTS[n.event].getLabel(n),
      }));
    },
  },
  template: `
        <div class="history-bg cursor-pointer" v-if="show" @click.self="$emit('close')">
            <div class="popup">
                <div class="header flex-center">
                    <h1>History</h1>
                    <spawn class="close cursor-pointer" @click="$emit('close')">X</span>
                </div>
                <div class="notifs-wrapper scrollbar">
                    <div v-for="notif in getNotifs()" :key="notif.id" class="line">
                        <div class="notif">
                            <span class="time outlined">{{notif.time}}</span>
                            <span class="label outlined"> : {{notif.label}}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        >
    `,
};
