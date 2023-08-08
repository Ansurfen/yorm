-- Copyright The yorm authors. All rights reserved.
-- Use of this source code is governed by a MIT-style
-- license that can be found in the LICENSE file.

---@diagnostic disable: lowercase-global

local orm_table = {}

function orm_table:exec()
    if not self.protected and type(self.db.driver.exec) == "function" then
        return self.db.driver.exec(self:build())
    end
    return "exec function not found", "exec function not found"
end

function orm_table:query()
    if not self.protected and type(self.db.driver.query) == "function" then
        return self.db.driver.query(self:build())
    end
    return "query function not found", "query function not found"
end

local orm_db = {}

function orm_db:table(name, fields)
    local i = 1
    local index2field = {}
    local fields_column = ""
    for k, v in pairs(fields) do
        v.pos = i
        local prototype = v.type.fmt
        v.type.fmt = function(in_)
            if in_ == nil then
                if type(v.not_null) == "boolean" and v.not_null then
                    return "NULL value and not default value", false
                end
                if v.default then
                    if type(prototype) == "function" then
                        return prototype(v.default), true
                    end
                    return v.default, true
                end
                if type(prototype) == "function" then
                    return prototype(in_), true
                end
                return "NULL", true
            end
            if type(prototype) == "function" then
                return prototype(in_), true
            end
            return in_, true
        end
        index2field[i] = v
        fields_column = fields_column .. k .. ", "
        i = i + 1
    end
    fields_column = string.sub(fields_column, 1, #fields_column - 2)
    local obj = {
        name = string.format("%s.%s", self.name, name),
        db = self,
        fields = fields,
        protected = true,
        index2field = index2field,
        fields_column = fields_column,
    }
    setmetatable(obj, { __index = orm_table })
    return obj
end

function orm_table:clone()
    local obj = {
        name = self.name,
        fields = self.fields,
        index2field = self.index2field,
        fields_column = self.fields_column,
        db = self.db
    }
    setmetatable(obj, { __index = orm_table })
    return obj
end

function orm_table:field(name)
    return string.format("%s(%s)", self.name, name)
end

function orm_table:in_(sql)
    if self.root then
        self = self:new()
    end
    return string.format("IN (%s)", sql:build())
end

function orm_table:insert(...)
    if self.protected then
        self = self:clone()
    end
    local valueses = {}
    for line, value in ipairs({ ... }) do
        local values = {}
        for k, v in pairs(value) do
            local pos = self.fields[k].pos
            if pos > #values then
                table.insert(values, self.fields[k].pos, v)
            else
                values[pos] = v
            end
        end
        for i = 1, #self.index2field, 1 do
            local field = self.index2field[i]
            values[i], ok = field.type.fmt(values[i])
            if not ok then
                local name
                for k, v in pairs(self.fields) do
                    if field == v then
                        name = k
                    end
                end
                yassert(string.format("%s at %d row(%s)", values[i], line, name))
            end
        end
        table.insert(valueses, values)
    end
    self.insert_clause = valueses
    return self
end

function orm_table:create(opt)
    if self.protected then
        self = self:clone()
    end
    local idx = string.find(self.name, "%.")
    local table_name = string.sub(self.name, idx + 1, #self.name)
    local sql = string.format("CREATE TABLE %s (\n", self.name)
    local rows = {}
    local constraints = {}
    local fk_cnt = 0
    local pk_cnt = 0
    for key, meta in pairs(self.fields) do
        local row = { key, meta.type.string }
        if meta.auto_increment ~= nil then
            table.insert(row, "auto_increment")
        end
        if meta.not_null ~= nil and meta.not_null then
            table.insert(row, "NOT NULL")
        else
            table.insert(row, "NULL")
        end
        if meta.comment ~= nil then
            table.insert(row, string.format("COMMENT '%s'", meta.comment))
        end
        if meta.primary ~= nil and meta.primary then
            local tmpl
            if pk_cnt == 0 then
                tmpl = "  CONSTRAINT %s_PK PRIMARY KEY (%s)"
            else
                tmpl = "  CONSTRAINT %s_PK_" .. pk_cnt .. " PRIMARY KEY (%s)"
            end
            table.insert(constraints, string.format(tmpl, table_name, key))
        end
        if meta.ref ~= nil then
            local tmpl
            if fk_cnt == 0 then
                tmpl = "  CONSTRAINT %s_FK FOREIGN KEY (%s) REFERENCES %s"
            else
                tmpl = "  CONSTRAINT %s_FK_" .. fk_cnt .. " FOREIGN KEY (%s) REFERENCES %s"
            end
            table.insert(constraints, string.format(tmpl, table_name, key, meta.ref))
            fk_cnt = fk_cnt + 1
        end
        table.insert(rows, "  " .. table.concat(row, " "))
    end
    for _, value in ipairs(constraints) do
        table.insert(rows, value)
    end
    local meta = {}
    table.insert(meta, string.format("ENGINE=%s", opt["engine"] or "InnoDB"))
    table.insert(meta, string.format("DEFAULT %s", opt["default"] or "CHARSET=uft8mb4"))
    table.insert(meta, string.format("COLLATE=%s", opt["collate"] or "utf8mb4_0900_ai_ci"))
    sql = sql .. string.format("%s\n)\n%s;", table.concat(rows, ",\n"), table.concat(meta, "\n"))
    self.create_clause = sql
    return self
end

---@return yorm_table
function orm_table:delete()
    if self.protected then
        self = self:clone()
    end
    self.delete_clause = "DELETE FROM " .. self.name
    return self
end

---@return yorm_table
function orm_table:where(condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.where_clause == nil then
        self.where_clause = {}
    end
    if type(condition) == "table" then
        for key, value in pairs(condition) do
            if type(key) == "number" then
                table.insert(self.where_clause, value)
            else
                table.insert(self.where_clause, string.format("%s %s", key, value))
            end
        end
    elseif type(condition) == "string" then
        table.insert(self.where_clause, string.format(condition, ...))
    end
    return self
end

---@return yorm_table
function orm_table:as(alias)
    if self.protected then
        self = self:clone()
    end
    self.alias = self.name .. " " .. alias
    return self
end

---@return yorm_table
function orm_table:right_join(tbl, condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.join_clause == nil then
        self.join_clause = {}
    end
    table.insert(self.join_clause, string.format("RIGHT JOIN %s ON %s", tbl.name, string.format(condition, ...)))
    return self
end

---@return yorm_table
function orm_table:left_join(tbl, condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.join_clause == nil then
        self.join_clause = {}
    end
    table.insert(self.join_clause, string.format("LEFT JOIN %s ON %s", tbl.name, string.format(condition, ...)))
    return self
end

---@return yorm_table
function orm_table:inner_join(tbl, condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.join_clause == nil then
        self.join_clause = {}
    end
    table.insert(self.join_clause, string.format("INNER JOIN %s ON %s", tbl.name, string.format(condition, ...)))
    return self
end

---@return yorm_table
function orm_table:limit(condition, ...)
    if self.protected then
        self = self:clone()
    end
    self.limit_clause = string.format(condition, ...)
    return self
end

---@return yorm_table
function orm_table:order_by(condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.order_by_clause == nil then
        self.order_by_clause = {}
    end
    if type(condition) == "string" then
        table.insert(self.order_by_clause, string.format(condition, ...))
    end
    return self
end

---@return yorm_table
function orm_table:group_by(condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.group_by_clause == nil then
        self.group_by_clause = {}
    end
    if type(condition) == "string" then
        table.insert(self.group_by_clause, string.format(condition, ...))
    end
    return self
end

---@return yorm_table
function orm_table:having(condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.having_clause == nil then
        self.having_clause = {}
    end
    if type(condition) == "table" then
        for key, value in pairs(condition) do
            if type(key) == "number" then
                table.insert(self.having_clause, value)
            else
                table.insert(self.having_clause, string.format("%s %s", key, value))
            end
        end
    elseif type(condition) == "string" then
        table.insert(self.having_clause, string.format(condition, ...))
    end
    return self
end

---@return yorm_table
function orm_table:from(condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.from_clause == nil then
        self.from_clause = {}
    end
    if type(condition) == "table" then
        for key, value in pairs(condition) do
            if type(key) == "number" then
                table.insert(self.from_clause, value)
            else
                table.insert(self.from_clause, string.format("%s %s", key, value))
            end
        end
    elseif type(condition) == "string" then
        table.insert(self.from_clause, string.format(condition, ...))
    end
    return self
end

---@return yorm_table
function orm_table:select(condition, ...)
    if self.protected then
        self = self:clone()
    end
    if self.select_clause == nil then
        self.select_clause = {}
    end
    if type(condition) == "table" then
        for key, value in pairs(condition) do
            if type(key) == "number" then
                table.insert(self.select_clause, value)
            else
                table.insert(self.select_clause, string.format("%s %s", key, value))
            end
        end
    elseif type(condition) == "string" then
        table.insert(self.select_clause, string.format(condition, ...))
    end
    return self
end

---@return yorm_table
function orm_table:update(opt)
    if self.protected then
        self = self:clone()
    end
    if self.update_clause == nil then
        self.update_clause = {}
    end
    for key, value in pairs(opt) do
        local field = self.fields[key]
        if field ~= nil then
            table.insert(self.update_clause, string.format("%s=%s", key, field.type.fmt(value)))
        end
    end
    return self
end

---@return string
function orm_table:build()
    local sql
    if self.delete_clause ~= nil then
        if self.where_clause ~= nil then
            sql = string.format("%s WHERE %s;", self.delete_clause, table.concat(self.where_clause, " AND "))
        else
            sql = self.delete_clause
        end
    elseif self.select_clause ~= nil then
        sql = "SELECT " .. table.concat(self.select_clause, " AND ")
        if self.from_clause ~= nil then
            sql = sql .. " FROM " .. table.concat(self.from_clause, ", ")
        else
            sql = sql .. string.format(" FROM %s ", self.alias or self.name)
        end
        if self.join_clause ~= nil then
            sql = sql .. " " .. table.concat(self.join_clause, " ")
        end
        if self.where_clause ~= nil then
            sql = sql .. " WHERE " .. table.concat(self.where_clause, " AND ")
        end
        if self.order_by_clause ~= nil then
            sql = sql .. " ORDER BY " .. table.concat(self.order_by_clause, ", ")
        end
        if self.order_by_clause ~= nil then
            sql = sql .. " GROUP BY " .. table.concat(self.group_by_clause, ", ")
        end
        if self.having_clause ~= nil then
            sql = sql .. " HAVING " .. table.concat(self.having_clause, ", ")
        end
        return sql .. ";"
    elseif self.insert_clause ~= nil then
        sql = string.format("INSERT INTO %s (%s) VALUES ", self.name, self.fields_column)
        for i, value in ipairs(self.insert_clause) do
            local raw = {}
            for ii = 1, #self.index2field, 1 do
                local v
                if value[ii] == nil then
                    v = "NULL"
                else
                    v = string.format([[%s]], value[ii])
                end
                table.insert(raw, v)
            end
            sql = sql .. string.format("(%s)", table.concat(raw, ", "))
            if i ~= #self.insert_clause then
                sql = sql .. " "
            end
        end
    elseif self.update_clause ~= nil then
        sql = string.format("UPDATE %s SET %s", self.name, table.concat(self.update_clause, ", "))
        if self.where_clause ~= nil then
            sql = sql .. " WHERE " .. table.concat(self.where_clause, " AND ")
        end
    elseif self.create_clause ~= nil then
        return self.create_clause
    end
    return sql .. ";"
end

local orm_driver = {}

function orm_driver:db(name)
    local obj = {
        name = name,
        driver = self
    }
    setmetatable(obj, { __index = orm_db })
    return obj
end

function orm_driver:use(table)
    return string.format("use %s;", table)
end

function orm_driver:set_exec(exec)
    self.exec = exec
end

function orm_driver:set_query(query)
    self.query = query
end

function orm_driver:create(db)
    return string.format("CREATE DATABASE IF NOT EXISTS %s;", db)
end

local driver = function(name)
    if name == "mysql" then
        local obj = {
            name = "mysql"
        }
        setmetatable(obj, { __index = orm_driver })
        return obj
    else
        yassert("no support")
    end
end

field_type = {
    bool = {
        string = "BOOL",
        fmt = function(n)
            return n
        end
    },
    integer = {
        string = "INTEGER",
        fmt = function(n)
            return n
        end
    },
    bigint = {
        string = "BIGINT",
        fmt = function(n)
            return n
        end
    },
    real = {
        string = "REAL",
        fmt = function(n)
            return n
        end
    },
    text = {
        string = "TEXT",
        fmt = function(in_)
            return string.format([['%s']], in_)
        end
    },
    varchar = function(n)
        return {
            string = string.format("varchar(%d)", n),
            fmt = function(in_)
                return string.format([['%s']], in_)
            end
        }
    end,
    blob = {
        string = "BLOB",
        fmt = function(n)
            return n
        end
    },
    datetime = {
        string = "DATATIME",
        fmt = function(n)
            return n
        end
    },
    double = {
        string = "DOUBLE",
        fmt = function(n)
            return n
        end
    }
}

return {
    driver = driver
}
