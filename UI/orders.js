const ArticleCmp = {
  props: ["article"],
  computed: {
    articleIcon() {
      switch (this.article.name) {
        case "Burger":
          switch (this.article.type) {
            case "Burger":
              return this.article.double ? "burger_double" : "burger";
            case "CheeseBurger":
              return this.article.double ? "cheese_double" : "cheese";
            case "ChickenBurger":
              return this.article.double ? "chicken_double" : "chicken";
            default:
              return "invalid";
          }
        case "Soda":
          return "soda";
        case "IceCream":
          switch (this.article.type) {
            case "Strawberry":
              return "icecream_strawberry";
            case "Milky":
              return "icecream_milky";
            default:
              return "invalid";
          }
        case "Potatoes":
          return "potatoes";
        case "Nugget":
          return "nugget";
        case "Coffee":
          return "coffee_cup";
        default:
          return "invalid";
      }
    },
    articleLabel() {
      let base = "";
      switch (this.article.name) {
        case "Burger":
          switch (this.article.type) {
            case "Burger":
              return this.article.double ? "Double Hamburger" : "Hamburger";
            case "CheeseBurger":
              return this.article.double ? "Double Cheesburger" : "Cheesburger";
            case "ChickenBurger":
              return this.article.double
                ? "Double Chicken Burger"
                : "Chicken Burger";
            default:
              return "?";
          }
        case "Soda":
          switch (this.article.type) {
            case "SplashCola":
              return "Splash Cola";
            case "LightSplashCola":
              return "Light Splash Cola";
            case "Youma":
              return "Youma";
            case "YoumaBerry":
              return "Youma Berry";
            case "Water":
              return "Water";
            case "MrHoop":
              return "Mr Hoop";
            default:
              return "?";
          }
        case "IceCream":
          base = "Ice Cream";
          switch (this.article.type) {
            case "Strawberry":
              return `Strawberry ${base}`;
            case "Milky":
              return `Vanilla ${base}`;
            default:
              return "?";
          }
        case "Potatoes":
          base = "French Fries";
          switch (this.article.type) {
            case "Small":
              return `${base} (Small)`;
            case "Medium":
              return `${base} (Medium)`;
            case "Large":
              return `${base} (Large)`;
            default:
              return "?";
          }
        case "Nugget":
          return "Chicken Nugget";
        case "Coffee":
          base = "Coffee";
          if (this.article.milkAmount > 0) {
            return `${base} with ${
              this.article.milkAmount == 2 ? "Extra " : ""
            }Milk`;
          } else if (this.article.coffeeAmount == 2) {
            return `Doubleshot ${base}`;
          }
          return base;
        default:
          return "?";
      }
    },
    formattedProducts() {
      let products = [];
      switch (this.article.name) {
        case "Burger":
          if (!this.article.products) {
            return products;
          }
          this.article.products.forEach((product) => {
            let icon = "invalid";
            switch (product.name) {
              case "Sauce":
                switch (product.type) {
                  case "Ketchup":
                    icon = "ketchup";
                    break;
                  case "Mustard":
                    icon = "mustard";
                    break;
                  case "Mayonnaise":
                    icon = "mayonnaise";
                    break;
                }
                break;
              case "Lettuce":
                icon = "lettuce";
                break;
              case "Onion":
                icon = "onion";
                break;
              case "Pickle":
                icon = "pickle";
                break;
              case "Tomato":
                icon = "tomato";
                break;
            }
            products.push({
              icon: icon,
              quantity: product.quantity,
            });
          });
        case "Soda":
          if (this.article.iceAmount > 0) {
            products.push({
              icon: "ice",
              quantity: this.article.iceAmount,
            });
          }
          return products;
        case "Coffee":
          if (this.article.coffeeAmount > 0) {
            products.push({
              icon: "coffee",
              quantity: this.article.coffeeAmount,
            });
          }
          if (this.article.milkAmount > 0) {
            products.push({
              icon: "milk",
              quantity: this.article.milkAmount,
            });
          }
          return products;
        case "IceCream":
        case "Potatoes":
        case "Nugget":
        default:
          return products;
      }
    },
  },
  template: `
    <div class="article">
        <div>
            <img :src="'UI/assets/'+articleIcon+'.png'" :title="articleLabel" :alt="articleLabel" />
            <span class="outlined">{{articleLabel}}</span>
        </div>
        <div>
            <div class="product-wrapper"v-for="(product, i) in formattedProducts" :key="i+'-'+product.icon">
                <img :src="'UI/assets/'+product.icon+'.png'" :title="product.icon" :alt="product.icon" />
                <span class="outlined">x{{product.quantity}}</span>
            </div>
        </div>
    </div>
  `,
};

const OrderCmp = {
  props: ["order"],
  setup(props) {
    return {
      open: ref(true),
    };
  },
  computed: {
    table() {
      return this.order.table - (this.order.drive ? 99 : 0);
    },
    parsedTime() {
      return parseGameTime(this.order.time);
    },
    cost() {
      return (Math.floor(this.order.cost * 100) / 100).toFixed(2);
    },
    burger() {
      return this.order.articles.find((art) => art.name === "Burger");
    },
    articlesButBurger() {
      return this.order.articles.filter((art) => art.name !== "Burger");
    },
  },
  template: `
        <div class="order">
            <div class="order-header">
                <div class="accordion-arrow" :class="{ open: open }" />
                <h2 class="flex-grow">{{order.drive ? "Drive Thru" : "Table No."}} {{table}}</h2>
                <div class="type-icon">
                    <div class="icon" :class="{ car: order.drive, ped: !order.drive }" />
                </div>
                <div class="time">
                    {{parsedTime}}
                </div>
                <div class="cost">
                    \${{cost}}
                </div>
                <div class="accordion-trigger cursor-pointer" @click="open = !open" />
            </div>
            <div class="order-details" v-if="open">
                <ArticleCmp v-if="burger"
                    :key="i+'-'+burger.name"
                    :article="burger" />
                <ArticleCmp v-for="(art, i) in articlesButBurger"
                    :key="i+'-'+art.name"
                    :article="art" />
            </div>
        </div>
    `,
};

const OrdersCmp = {
  props: ["orders"],
  template: `
        <div class="container">
            <div class="header-spacing" />
            <div class="orders flex-grow scrollbar">
                <OrderCmp v-for="order in orders" :key="order.id" :order="order" />
            </div>
        </div>
    `,
};
