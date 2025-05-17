const CheckCmp = {
  props: ["state"],
  template: `
        <div class="cursor-pointer checkbox" @click="$emit('toggle')">
            <svg v-if="state === true" class="checked" width="100%" height="100%" viewBox="0 0 200 200">
                <path d="M 195 7 L 77 144 L 38 84 L 4 89 L 66 199 L 90 200 L 197 6 Z" />
            </svg>
        </div>
    `,
};

const HeaderCmp = {
  props: ["driveThruState", "otherState"],
  template: `
          <header class="flex-center">
            <div class="header-btns">
              <img src="UI/assets/history.svg" alt="History" title="History" @click="$emit('open-history')"/>
            </div>
            <h1>Customer Orders</h1>
            <div class="checks flex-center">
              <span class="cursor-pointer" @click="$emit('toggle', true)">Drive Thru</span>
              <CheckCmp :state="driveThruState" @toggle="$emit('toggle', true)" />
              <span class="cursor-pointer" @click="$emit('toggle', false)">Other</span>
              <CheckCmp :state="otherState" @toggle="$emit('toggle', false)" />
            </div>
          </header>
      `,
};
