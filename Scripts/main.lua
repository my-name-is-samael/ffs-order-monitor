-- UTILS

function string.split(str, sep)
    local t = {}
    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, s)
    end
    return t
end

function table.compare(arr1, arr2)
    if #arr1 ~= #arr2 then
        return false
    end
    for i, v in ipairs(arr1) do
        if arr2[i] ~= v then
            return false
        end
    end
    return true
end

local function dirExists(path)
    if string.sub(path, -1) ~= "/" then
        -- add last slash if missing
        path = path .. "/"
    end
    local status, err, code = os.rename(path, path)
    if not status and code == 13 then
        -- permission denied but folder exists
        return true
    end
    return status
end

-- MOD

local M = {
    -- CONSTANTS
    logTag = "OrdersMonitor",
    exportedOrdersFile = "Mods/OrdersMonitor/orders_export.js",
    exportedEventsFile = "Mods/OrdersMonitor/events_export.js",
    PED_EVENTS = {
        ARRIVED = "ped_arrived",
        ORDER_VALIDATED = "ped_order_validated",
        SERVED_WELL = "ped_served_well",
        SERVED_BADLY = "ped_served_badly",
        LEFT = "ped_left",
    },
    CAR_EVENTS = {
        ARRIVED = "car_arrived",
        ORDER_VALIDATED = "car_order_validated",
        SERVED_WELL = "car_served_well",
        SERVED_BADLY = "car_served_badly",
        LEFT = "car_left",
    },

    -- DATA
    cachedOrders = {},
    cachedSortedOrders = {},
    tableCustomers = {},
    driveThruCustomers = {},
    events = {},
}

local function log(msg, ar)
    msg = string.format("[%s] %s\n", M.logTag, tostring(msg))
    print(msg)
    if ar then
        pcall(ar.Log, ar, msg)
    end
end

function M.getOrderByID(id)
    local orders = FindAllOf("BP_Order_C") or {}
    for _, order in pairs(orders) do
        if order:IsValid() and order:GetFName():ToString():find(id) then
            return order
        end
    end
    return nil
end

local function getSimpleSortedOrders(orders)
    local res = {}
    local iSortOrder = 1
    while iSortOrder <= #orders do
        local id = orders[iSortOrder]:GetFName():ToString()
        table.insert(res, id)
        iSortOrder = iSortOrder + 1
    end
    return res
end

function M.exportOrders(orders)
    if not orders then
        ---@class ABP_OrderManager_C
        local orderManager = FindFirstOf("BP_OrderManager_C")
        orders = orderManager.Orders
    end
    local function getOrder(orderID, callback)
        local i = 1
        while i <= #orders do
            if orders[i]:GetFName():ToString() == orderID then
                callback(orders[i])
                break
            end
            i = i + 1
        end
    end
    local sortedOrders = getSimpleSortedOrders(orders)
    local changes = false

    -- remove done orders
    for i, orderID in ipairs(M.cachedSortedOrders) do
        if sortedOrders[i] ~= orderID then
            -- order left
            table.remove(M.cachedSortedOrders, i)
            table.remove(M.cachedOrders, i)
            changes = true
        end
    end

    -- add new orders
    if not table.compare(sortedOrders, M.cachedSortedOrders) then
        for iOrder, orderID in ipairs(sortedOrders) do
            if not M.cachedSortedOrders[iOrder] then
                ---@param order ABP_Order_C
                getOrder(orderID, function(order)
                    changes = true
                    local expOrder = {
                        id = tonumber(orderID),
                        drive = order.DriveThruOrder,
                        table = order.TableNumber,
                        cost = order.OrderCost,
                        time = order.OrderTime, -- 0 -> 43200
                        articles = {},
                    }

                    local articles = order.OrderTray[1].Products_3_992C8D0B4EDE004EBA7C06B2928C908B
                    local iArticle = 1
                    while iArticle <= #articles do
                        ---@class FFOrderProduct
                        local article = articles[iArticle]
                        local expArticle = {}
                        expArticle.name = article.ProductTag_3_3B00D46148155AA5CE7952B5A4571C49.TagName:ToString()
                            :gsub("Restaurant.Order.", "")
                        local otherTags = article.OtherTags_14_1E00A760490F5051876F16B07CDDE4E5.GameplayTags
                        expArticle.type = ""

                        if expArticle.name == "Burger" and #otherTags > 1 and
                            otherTags[2].TagName:ToString():find("Double") then
                            expArticle.double = true
                        elseif expArticle.name == "Soda" then
                            expArticle.iceAmount = 0
                            if #otherTags > 1 then
                                if otherTags[2].TagName:ToString():find("ExtraIced") then
                                    expArticle.iceAmount = 2
                                elseif otherTags[2].TagName:ToString():find("Iced") then
                                    expArticle.iceAmount = 1
                                end
                            end
                        end
                        if #otherTags > 0 then
                            expArticle.type = otherTags[1].TagName:ToString()
                                :gsub(string.format("Restaurant.Order.%s.", expArticle.name), "")
                                :gsub("Restaurant.Product.FryCup", "")
                        end
                        if expArticle.name == "Coffee" then
                            expArticle.coffeeAmount = 1
                            expArticle.milkAmount = 0
                            if expArticle.type == "ExtraCoffee" then
                                expArticle.coffeeAmount = 2
                            elseif expArticle.type == "MilkyCoffee" then
                                expArticle.milkAmount = 1
                            elseif expArticle.type == "ExtraMilkyCoffee" then
                                expArticle.milkAmount = 2
                            end
                            expArticle.type = nil
                        elseif expArticle.name == "Nugget" then
                            expArticle.type = nil
                        end

                        expArticle.products = {}
                        local products = article.ExtraData_10_6423F9764BC373170F21019B4372822F
                        local iProduct = 1
                        while iProduct <= #products do
                            local prodName = products[iProduct]:ToString()
                                :gsub("Restaurant.Product.Ingredient.", "")
                            local prodQuantity = tonumber(products[iProduct + 1]:ToString())
                            local prodType = ""
                            if prodName:find(".") then
                                local parts = string.split(prodName, ".")
                                prodName = parts[1]
                                prodType = parts[2]
                            end
                            local expProduct = {
                                name = prodName,
                                type = prodType,
                                quantity = prodQuantity,
                            }
                            table.insert(expArticle.products, expProduct)
                            iProduct = iProduct + 2
                        end
                        if #expArticle.products == 0 then
                            expArticle.products = nil
                        end
                        table.insert(expOrder.articles, expArticle)
                        iArticle = iArticle + 1
                    end
                    table.insert(M.cachedOrders, expOrder)
                    table.insert(M.cachedSortedOrders, orderID)
                end)
            end
        end
    end

    if changes then
        local str = #M.cachedOrders > 0 and require("json").encode(M.cachedOrders) or "[]"
        local file, err = io.open(M.exportedOrdersFile, "w+")
        if file then
            file:write("function GET_ORDERS() { return " .. str .. "; }")
            file:close()
        else
            log(err)
        end
    end
end

local function exportEvents()
    local str = #M.events > 0 and require("json").encode(M.events) or "[]"
    local file, err = io.open(M.exportedEventsFile, "w+")
    if file then
        file:write("function GET_EVENTS() { return " .. str .. "; }")
        file:close()
    else
        log(err)
    end
end

function M.addEvent(isPed, event, tableNumber)
    ---@class ABP_BakeryGameState_Ingame_C
    local gameState = FindFirstOf("BP_BakeryGameState_Ingame_C")
    table.insert(M.events, {
        time = gameState.GameTime,
        event = event,
        table = tableNumber,
    })
    exportEvents()
end

function M.clearEvents()
    M.events = {}
    exportEvents()
end

local function getCustomerID(Customer)
    local name = Customer:GetFullName()
    if not name then
        name = Customer:GetFName():ToString()
    end
    local id
    if name then
        id = name:match("Customer_C_(%d+)$")
    end
    return tonumber(id)
end

M.hooks = {
    SetIsRestaurantRunning = { -- on open restaurant trigger, clear events
        key =
        "/Game/Blueprints/GameMode/GameState/BP_BakeryGameState_Ingame.BP_BakeryGameState_Ingame_C:SetIsRestaurantRunning",
        hookFn = function(self, GameState, openState)
            M.clearEvents()
            M.exportOrders({})
        end
    },
    OnMainMenuConfirmation = { -- on return to menu trigger, clear events
        key = "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnMainMenuConfirmation",
        hookFn = function(self, bConfirmed)
            if bConfirmed:get() then
                M.clearEvents()
                M.exportOrders({})
            end
        end,
    },
    OnQuitConfirmation = { -- on quit game, clear events and orders
        key = "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnQuitConfirmation_Event",
        hookFn = function(self, bConfirmed)
            if bConfirmed:get() then
                M.clearEvents()
                M.exportOrders({})
            end
        end,
    },
    OnRepOrders = {
        key = "/Game/Blueprints/Gameplay/Order/BP_OrderManager.BP_OrderManager_C:OnRep_Orders",
        hookFn = function(self, OrderManager)
            M.exportOrders(OrderManager:get().Orders)
        end
    },
    AddOrder = { -- on customer order validated (peds and cars)
        key = "/Game/Blueprints/Gameplay/Order/BP_OrderManager.BP_OrderManager_C:AddOrder",
        hookFn = function(self, OrderManager, OrderToAdd)
            local customerId = getCustomerID(OrderToAdd:get().Customer)
            local isPed = not OrderToAdd:get().Customer.CustomerDriveThruCar:IsValid()
            local tableNumber = OrderToAdd:get().Customer:GetCustomerTableNumber()
            if isPed then
                M.tableCustomers[customerId] = {
                    table = tableNumber,
                    served = false,
                }
            else
                M.driveThruCustomers[customerId] = {
                    table = tableNumber,
                    served = false,
                }
            end
            M.addEvent(isPed, isPed and M.PED_EVENTS.ORDER_VALIDATED or M.CAR_EVENTS.ORDER_VALIDATED, tableNumber)
        end
    },
    SetCustomerState = { -- on ped customer state update (when served and leave)
        key = "/Game/Blueprints/Characters/Customer/BP_Customer.BP_Customer_C:SetCustomerState",
        hookFn = function(self, Customer, CustomerState)
            local state = CustomerState:get()
            local customerId = getCustomerID(Customer:get())
            if state == 5 then -- order served well
                if M.tableCustomers[customerId] then
                    M.tableCustomers[customerId] = nil
                    M.addEvent(true, M.PED_EVENTS.SERVED_WELL, M.tableCustomers[customerId].table)
                end
            elseif state == 6 then -- leave / served badly
                if M.tableCustomers[customerId] then
                    if M.tableCustomers[customerId].served then
                        -- served badly
                        M.addEvent(true, M.PED_EVENTS.SERVED_BADLY, M.tableCustomers[customerId].table)
                    else
                        -- leave
                        M.addEvent(true, M.PED_EVENTS.LEFT, M.tableCustomers[customerId].table)
                    end
                    M.tableCustomers[customerId] = nil
                else
                    -- not validated order customer left
                    M.addEvent(true, M.PED_EVENTS.LEFT)
                end
            end
        end
    },
    OnTrayPlacedOnTable = { -- when placing a tray on a table, mark to distinguish between leave and served badly
        key =
        "/Game/Blueprints/Gameplay/CustomerTables/BP_Customer_TableBase.BP_Customer_TableBase_C:TableArea_OnItemPlaced",
        hookFn = function(self, TableBase, Item)
            local id = getCustomerID(TableBase:get().Customer)
            if M.tableCustomers[id] then
                M.tableCustomers[id].served = true
            end
        end,
    },
    SayHello = { -- on customer arrived
        key = "/Game/Blueprints/Characters/Customer/BP_Customer.BP_Customer_C:SayHello_OnMulticast",
        hookFn = function(self, Customer)
            local isPed = not Customer:get().CustomerDriveThruCar:IsValid()
            M.addEvent(isPed, isPed and M.PED_EVENTS.ARRIVED or M.CAR_EVENTS.ARRIVED)
        end,
    },
    OnOrderDelivered = { -- on car customer served
        key = "/Game/Blueprints/Gameplay/DriveThru/BP_DriveThruCar.BP_DriveThruCar_C:OnRep_bOrderDelivered",
        hookFn = function(self, DriveThruCar)
            local customerId = getCustomerID(DriveThruCar:get().DriverCustomer)
            if M.driveThruCustomers[customerId] then
                M.driveThruCustomers[customerId].served = true
            end
        end,
    },
    UpdatePatience = { -- car customer ran out of patience
        key = "/Game/Blueprints/Gameplay/DriveThru/BP_DriveThruCar.BP_DriveThruCar_C:UpdatePatience",
        hookFn = function(self, DriveThruCar)
            local customerId = getCustomerID(DriveThruCar:get().DriverCustomer)
            if DriveThruCar:get():HasRunOutOfPatience() then
                if M.driveThruCustomers[customerId] then
                    M.addEvent(false, M.CAR_EVENTS.LEFT, M.driveThruCustomers[customerId].table)
                else
                    M.addEvent(false, M.CAR_EVENTS.LEFT)
                end
            end
        end,
    },
    DriveThruLeavingEvent = { -- on car customer leave
        key = "/Game/Blueprints/Gameplay/DriveThru/BP_DriveThruCar.BP_DriveThruCar_C:DriveThruLeavingEvent",
        hookFn = function(self, DriveThruCar)
            local customerId = getCustomerID(DriveThruCar:get().DriverCustomer)
            local customerData = M.driveThruCustomers[customerId]
            if customerData then
                if not customerData.served then
                    -- left
                    M.addEvent(false, M.CAR_EVENTS.LEFT, customerData.table)
                else
                    local score = DriveThruCar:get().DriverCustomer.ScoredOrderTip
                    M.addEvent(false, score > 0 and M.CAR_EVENTS.SERVED_WELL or M.CAR_EVENTS.SERVED_BADLY,
                        customerData.table)
                end
                M.driveThruCustomers[customerId] = nil
            end
        end,
    }
}
function M.toggleHooks()
    for _, h in pairs(M.hooks) do
        if not h.enabled and (not h.condFn or h:condFn()) then
            h.enabled, h.pre, h.post = pcall(RegisterHook, h.key, function(ctxt, ...) h:hookFn(ctxt, ...) end)
        elseif h.enabled and h.condFn and not h:condFn() then
            if pcall(UnregisterHook, h.key, h.pre, h.post) then
                h.enabled, h.pre, h.pos = nil, nil, nil
            end
        end
    end
end

function M.onInit()
    if dirExists("ue4ss/") then
        -- detect beta version of UE4SS
        M.exportedOrdersFile = "ue4ss/" .. M.exportedOrdersFile
        M.exportedEventsFile = "ue4ss/" .. M.exportedEventsFile
    end
    LoopAsync(1000, function()
        -- loop to enable hooks
        M.toggleHooks()
        return false
    end)

    log("Mod Loaded!")
end

M.onInit()
