---@enum PedEvent
local PED_EVENTS = {
    ARRIVED = "ped_arrived",
    ORDER_VALIDATED = "ped_order_validated",
    SERVED_WELL = "ped_served_well",
    SERVED_BADLY = "ped_served_badly",
    LEFT = "ped_left",
}

---@enum CarEvent
local CAR_EVENTS = {
    ARRIVED = "car_arrived",
    ORDER_VALIDATED = "car_order_validated",
    SERVED_WELL = "car_served_well",
    SERVED_BADLY = "car_served_badly",
    LEFT = "car_left",
}

---@class OrdersMonitor : ModModule
local M = {
    Author = "TontonSamael",
    Version = 1,

    -- DATA
    ExportedOrdersFile = "Mods/OrdersMonitor/orders_export.js",
    ExportedEventsFile = "Mods/OrdersMonitor/events_export.js",
    cachedOrders = {},
    cachedSortedOrders = {},
    tableCustomers = {},
    driveThruCustomers = {},
    events = {},
    quitBypass = false,
}

local function GetSimpleSortedOrders(Orders)
    local res = {}
    local iSortOrder = 1
    while iSortOrder <= #Orders do
        local id = Orders[iSortOrder]:GetFName():ToString()
        table.insert(res, id)
        iSortOrder = iSortOrder + 1
    end
    return res
end

local function ExportOrders(Orders)
    if not Orders then
        ---@type ABP_OrderManager_C|UObject
        local OrderManager = FindFirstOf("BP_OrderManager_C")
        if not OrderManager:IsValid() then
            return
        end
        Orders = OrderManager.Orders
    end
    local function getOrder(orderID, callback)
        local i = 1
        while i <= #Orders do
            if Orders[i]:GetFName():ToString() == orderID then
                callback(Orders[i])
                break
            end
            i = i + 1
        end
    end
    local sortedOrders = GetSimpleSortedOrders(Orders)
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
        local file, err = io.open(M.ExportedOrdersFile, "w+")
        if file then
            file:write("function GET_ORDERS() { return " .. str .. "; }")
            file:close()
        else
            Log(M, LOG.ERR, err)
        end
    end
end

local function ExportEvents()
    local str = #M.events > 0 and require("json").encode(M.events) or "[]"
    local file, err = io.open(M.ExportedEventsFile, "w+")
    if file then
        file:write("function GET_EVENTS() { return " .. str .. "; }")
        file:close()
    else
        Log(M, LOG.ERR, err)
    end
end

---@param ModManager ModManager
---@param isPed boolean
---@param event PedEvent|CarEvent
---@param tableNumber? number
local function AddEvent(ModManager, isPed, event, tableNumber)
    table.insert(M.events, {
        time = ModManager.GameState.GameTime,
        event = event,
        table = tableNumber,
    })
    ExportEvents()
end

function ClearEvents()
    M.events = {}
    ExportEvents()
end

function ClearOrders()
    M.cachedOrders = {}
    M.cachedSortedOrders = {}
    local file, err = io.open(M.ExportedOrdersFile, "w+")
    if file then
        file:write("function GET_ORDERS() { return []; }")
        file:close()
    else
        Log(M, LOG.ERR, err)
    end
end

local function ExtractCustomerID(Customer)
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

---@param ModManager ModManager
local function InitHooks(ModManager)
    ModManager.AddHook(M, "SetIsRestaurantRunning",
        "/Game/Blueprints/GameMode/GameState/BP_BakeryGameState_Ingame.BP_BakeryGameState_Ingame_C:SetIsRestaurantRunning",
        function(M2, GameState, openState)
            if openState:get() then
                ClearEvents()
                ClearOrders()
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "QuitToMainMenu",
        "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnMainMenuConfirmation",
        function(M2, EscapeMenu, bConfirmed)
            if bConfirmed:get() then
                M.quitBypass = true
                ExecuteWithDelay(500, function()
                    M.quitBypass = false
                end)
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "QuitGame",
        "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnQuitConfirmation_Event",
        function(M2, EscapeMenu, bConfirmed)
            if bConfirmed:get() then
                M.quitBypass = true
                ExecuteWithDelay(500, function()
                    M.quitBypass = false
                end)
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "OnRepOrders",
        "/Game/Blueprints/Gameplay/Order/BP_OrderManager.BP_OrderManager_C:OnRep_Orders",
        function(M2, OrderManager)
            ExportOrders(OrderManager:get().Orders)
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "AddOrder",
        "/Game/Blueprints/Gameplay/Order/BP_OrderManager.BP_OrderManager_C:AddOrder",
        function(M2, OrderManager, OrderToAdd)
            local customerId = ExtractCustomerID(OrderToAdd:get().Customer)
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
            AddEvent(ModManager, isPed, isPed and PED_EVENTS.ORDER_VALIDATED or CAR_EVENTS.ORDER_VALIDATED,
                tableNumber)
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "SetCustomerState",
        "/Game/Blueprints/Characters/Customer/BP_Customer.BP_Customer_C:SetCustomerState",
        function(M2, Customer, CustomerState)
            local state = CustomerState:get()
            local customerId = ExtractCustomerID(Customer:get())
            if state == 5 then -- order served well
                if M.tableCustomers[customerId] then
                    M.tableCustomers[customerId] = nil
                    AddEvent(ModManager, true, PED_EVENTS.SERVED_WELL, M.tableCustomers[customerId].table)
                end
            elseif state == 6 then -- leave / served badly
                if M.tableCustomers[customerId] then
                    if M.tableCustomers[customerId].served then
                        -- served badly
                        AddEvent(ModManager, true, PED_EVENTS.SERVED_BADLY, M.tableCustomers[customerId].table)
                    else
                        -- leave
                        AddEvent(ModManager, true, PED_EVENTS.LEFT, M.tableCustomers[customerId].table)
                    end
                    M.tableCustomers[customerId] = nil
                elseif not M.quitBypass then
                    -- not validated order customer left
                    AddEvent(ModManager, true, PED_EVENTS.LEFT)
                end
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "OnTrayPlacedOnTable",
        "/Game/Blueprints/Gameplay/CustomerTables/BP_Customer_TableBase.BP_Customer_TableBase_C:TableArea_OnItemPlaced",
        function(M2, TableBase, Item)
            local id = ExtractCustomerID(TableBase:get().Customer)
            if M.tableCustomers[id] then
                M.tableCustomers[id].served = true
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "SayHello",
        "/Game/Blueprints/Characters/Customer/BP_Customer.BP_Customer_C:SayHello_OnMulticast",
        function(M2, Customer)
            local isPed = not Customer:get().CustomerDriveThruCar:IsValid()
            AddEvent(ModManager, isPed, isPed and PED_EVENTS.ARRIVED or CAR_EVENTS.ARRIVED)
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "OnOrderDelivered",
        "/Game/Blueprints/Gameplay/DriveThru/BP_DriveThruCar.BP_DriveThruCar_C:OnRep_bOrderDelivered",
        function(M2, DriveThruCar)
            local customerId = ExtractCustomerID(DriveThruCar:get().DriverCustomer)
            if M.driveThruCustomers[customerId] then
                M.driveThruCustomers[customerId].served = true
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "UpdatePatience",
        "/Game/Blueprints/Gameplay/DriveThru/BP_DriveThruCar.BP_DriveThruCar_C:UpdatePatience",
        function(M2, DriveThruCar)
            local customerId = ExtractCustomerID(DriveThruCar:get().DriverCustomer)
            if DriveThruCar:get():HasRunOutOfPatience() then
                if M.driveThruCustomers[customerId] then
                    AddEvent(ModManager, false, CAR_EVENTS.LEFT, M.driveThruCustomers[customerId].table)
                else
                    AddEvent(ModManager, false, CAR_EVENTS.LEFT)
                end
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
    ModManager.AddHook(M, "DriveThruLeavingEvent",
        "/Game/Blueprints/Gameplay/DriveThru/BP_DriveThruCar.BP_DriveThruCar_C:DriveThruLeavingEvent",
        function(M2, DriveThruCar)
            local customerId = ExtractCustomerID(DriveThruCar:get().DriverCustomer)
            local customerData = M.driveThruCustomers[customerId]
            if customerData then
                if not customerData.served then
                    -- left
                    AddEvent(ModManager, false, CAR_EVENTS.LEFT, customerData.table)
                else
                    local score = DriveThruCar:get().DriverCustomer.ScoredOrderTip
                    AddEvent(ModManager, false, score > 0 and CAR_EVENTS.SERVED_WELL or CAR_EVENTS.SERVED_BADLY,
                        customerData.table)
                end
                M.driveThruCustomers[customerId] = nil
            end
        end,
        function(M2) return M2.AppState == APP_STATES.IN_GAME end)
end

---@param ModManager ModManager
function M.Init(ModManager)
    M.ExportedOrdersFile = ModManager.GetAbsolutePath(M) .. "orders_export.js"
    M.ExportedEventsFile = ModManager.GetAbsolutePath(M) .. "events_export.js"

    InitHooks(ModManager)
end

return M
