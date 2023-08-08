local yorm = import("./index")
---@type yorm_driver
local mysql_orm = yorm.driver("mysql")
-- mysql_orm:use("bank");
-- mysql_orm:databases();
---@type yorm_db
local bank1 = mysql_orm:db("bank")
local cb = bank1:table("card", {
    cardID = { type = field_type.varchar(32), auto_increment = true, primary = true },
    openDate = { type = field_type.datetime, not_null = true },
    balance = { type = field_type.double, not_null = true }
})

---@type yorm_table
local cs = bank1:table("customer", {
    customerID = {
        type = field_type.integer,
        primary = true,
        auto_increment = true,
        not_null = true,
        comment = "customer's ID to guard unique"
    },
    customerName = { type = field_type.varchar(20), not_null = true },
    ID = { type = field_type.varchar(18), not_null = true },
    telephone = { type = field_type.varchar(11), not_null = true },
    address = { type = field_type.varchar(50), ref = cb:field("balance"), default = "nil" }
})

print(cs:create({
    engine = "InnoDB",
}):build())
print(cs:delete():build())
print(cs:delete():where("id=0"):build())
print(cs:as("bt"):select("bt.id, bt.type"):left_join(cb:as("bc"), "bc.id = bt.id AND %d", 1)
    :right_join(cb:as("cs"), "cs.id = bc.id"):build())
print(cs:insert({ customerID = 5, customerName = "test0", ID = 123456789, telephone = 777 }):build())
print(cs:insert(
    { customerName = "test1", ID = 0, telephone = 123456, customerID = 105 },
    { customerName = "test2", ID = 1, telephone = 789101, customerID = 679 }):build())
print(cs:update({
    customerName = "10",
}):where("id=1"):build())
print(cs:select({
    customerName = "= Customer%%"
}):build())
print(cs:from({
    customer = "c",
    bank_card = "bc"
}):select("bc.cardID"):where({
    "bc.customerID = c.customerID",
    "bc.customerID = 1 "
}):build())
print(cs:select("*"):from("transaction as bt"):where({
    cardID = cs:in_(cs:from("customer = c, bank_card = bc"):select("bc.cardID"):where(
        "bc.customerID = c.customerID AND bc.customerID = %d ", 1)),
    type = "= 0",
    "bc.customerID  = 1"
}):build())
print(cs:delete():build())

print(cs:select("*"):where("salary > 0"):group_by("id"):
having("prize > 0"):order_by("id desc"):limit("m, n"):build())

mysql_orm:set_exec(function(cmd)
    print("start to exec")
    print(cmd)
    print("exec finished")
    return "", nil
end)

print(cs:select("*"):exec())
print(cs:select("*"):query())