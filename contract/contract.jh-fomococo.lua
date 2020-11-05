DEVELOPER_PROPORTION = 0.05 --开发者占比
BOUNS_PROPORTION = 0.75 --分红占比
FINAL_PRIZE = 0.2

local function _read_data()
    -- 读数据
    read_list = {public_data = {}, private_data = {}}
    chainhelper:read_chain()
end

local function _save_data()
    -- 写数据
    write_list = {public_data = {}, private_data = {}}
    chainhelper:write_chain()
end

function init()
    assert(chainhelper:is_owner(), "#没有权限#")
    _read_data()
    --assert(public_data.count == nil, "#游戏已经开始了#");
    public_data = {
        count = 0,
        timestamp = chainhelper:time(),
        countrys = {
            wei = {num = 0, price = 0},
            shu = {num = 0, price = 0},
            wu = {num = 0, price = 0}
        }
    }
    _save_data()
end

function Buy(arg_country, arg_num)
    _read_data()
    arg_num = math.floor(arg_num)
    if private_data.countrys == nil then 
        private_data.countrys ={
            wei = {num = 0, price = 0},
            shu = {num = 0, price = 0},
            wu = {num = 0, price = 0}
        }
    end
    local public_country = public_data.countrys[arg_country]
    local private_country = private_data.countrys[arg_country]
    local amount = arg_num * 10000000
    local bonus_amount = math.floor(amount * BOUNS_PROPORTION / 3)
    local final_prize = math.floor(amount * FINAL_PRIZE)
    local dev_amount = math.floor(amount * DEVELOPER_PROPORTION)
    for name, country in pairs(public_data.countrys) do
        if country.num ~= 0 then 
            public_data.countrys[name].price = country.price + math.floor(bonus_amount/country.num)
        end
    end
    if private_country.num == 0 then
        private_country.price = public_country.price
    else
        local sub_price = public_country.price - private_country.price
        local bonus_total = sub_price * private_country.num
        local proportion = bonus_total / (private_country.num + arg_num)
        local new_sub_price =  math.ceil(public_country.price - proportion)
        private_country.price = new_sub_price
    end
    private_country.num = private_country.num + arg_num
    public_country.num = public_country.num + arg_num
    _save_data()
end

function Withdraw()
    -- public_data = {}
    private_data = {}
    write_list = {private_data = {}}
    chainhelper:log(chainhelper:number_max())
    chainhelper:write_chain()
end
