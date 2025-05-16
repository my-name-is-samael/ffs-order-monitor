# Modified ffs-order-monitor
Modified OrderMonitor Mod for Fast Food Simulator

This mod is still under development and not meant for non-developer users
For those who looking for original version: https://www.nexusmods.com/fastfoodsimulator/mods/23


## Difference with unmodified version
This mod is targeted to serve OrderMonitor.html in the web server instead of opening local file, thus the web page can be opened on your mobile phone, another computer or by other friends.
With the following modifications for now:
- Narrow screen supported
- Socketio connection instead of fetching
### Other targets
- [ ] Switch between different screen version (Original, narrow)
- [ ] Screen in KDS style
- [ ] Display order waiting time
- [ ] Display order progress (cross out items already on the tray)

Under the ~~hood~~ table
- [ ] Refactor into a Vue project
- [ ] push new event/order only instead of all event/order


## How to install
- UE4SS required ([Guide](https://docs.ue4ss.com/dev/installation-guide.html), [Download](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1))
1. Download this mod
2. Extract zip file into the <game_path>\ProjectBakery\Binaries\Win64\Mods\
PS: OrdersMonitor.html should be located at <game_path>\ProjectBakery\Binaries\Win64\Mods\OrdersMonitor\OrdersMonitor.html
3. Start the game



## How to start the server
- Node.js required
- First time: `npm install`
- Afterwards: `node server.js`

