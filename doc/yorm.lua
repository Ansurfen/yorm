-- Copyright The yorm authors. All rights reserved.
-- Use of this source code is governed by a MIT-style
-- license that can be found in the LICENSE file.

---@diagnostic disable: duplicate-doc-field

---@meta _

---@class yorm_field
---@field type field_type
---@field auto_increment? boolean
---@field not_null? boolean
---@field primary? boolean
---@field comment? string
---@field ref? table|string

---@class yorm_db
---@field table fun(self: yorm_db, name: string, feilds: table<string, yorm_field>)

---@class yorm_table
---@field clone fun(): yorm_table
---@field field fun(name: string): string
---@field create fun(self: yorm_table, opt: table)
---@field delete fun(self: yorm_table): yorm_table
---@field build fun(self: yorm_table): string
---@field where fun(self: yorm_table, condition: string, ...): yorm_table
---@field where fun(self: yorm_table, condition: table): yorm_table
---@field select fun(self: yorm_table, condition: string, ...): yorm_table
---@field select fun(self: yorm_table, condition: table): yorm_table
---@field from fun(self: yorm_table, condition: string, ...): yorm_table
---@field from fun(self: yorm_table, condition: table): yorm_table
---@field having fun(self: yorm_table, condition: string, ...): yorm_table
---@field having fun(self: yorm_table, condition: table): yorm_table
---@field group_by fun(self: yorm_table, condition: string, ...): yorm_table
---@field group_by fun(self: yorm_table, condition: table): yorm_table
---@field order_by fun(self: yorm_table, condition: string, ...): yorm_table
---@field order_by fun(self: yorm_table, condition: table): yorm_table
---@field left_join fun(self: yorm_table, condition: string, ...): yorm_table
---@field right_join fun(self: yorm_table, condition: string, ...): yorm_table
---@field inner_join fun(self: yorm_table, condition: string, ...): yorm_table
---@field limit fun(self: yorm_table, condition: string, ...): yorm_table
---@field as fun(self: yorm_table, alias: string): yorm_table
---@field insert fun(self: yorm_table, ...): yorm_table
---@field update fun(self: yorm_table, setter: table): yorm_table
---@field in_ fun(self: yorm_table, sql: yorm_table): string
---@field exec fun(self: yorm_table): string, err
---@field query fun(self: yorm_table): table, err

---@class yorm
---@field driver fun(name: string): yorm_driver

---@class yorm_driver
---@field db fun(self: yorm_driver, name: string): yorm_db
---@field set_exec fun(self: yorm_driver, cb: fun(sql: string): string, err)
---@field set_query fun(self: yorm_driver, cb: fun(sql: string): table, err)

---@enum field_type
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