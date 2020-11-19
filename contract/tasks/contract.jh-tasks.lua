CONTRACT_NAME = "contract.jh-tasks"
CONTRACT_CONFIGS = "contract.jh-configs"
local function _ContractConfig()
    if G_CONFIG == nil then G_CONFIG = import_contract(CONTRACT_CONFIGS) end
end

local function _read_public_data()
    return chainhelper:get_contract_public_data(CONTRACT_NAME)
end

local function _get_tasks_info(nft_id)
    local nft = cjson.decode(chainhelper:get_nft_asset(nft_id))
    assert(nft.world_view == G_CONFIG.TASKS_WORLD_VIEW,
           "#世界观不正确！#")
    local tasks = {}
    for _, contract in pairs(nft.describe_with_contract) do
        if contract[1] == contract_base_info.id then
            for _, describe in pairs(contract[2]) do
                tasks[describe[1]] = cjson.decode(describe[2])
            end
            return tasks
        end
    end
    return tasks
end

local function _create_tasks_nft()
    local base_info = {name = private_data.attrs.name .. "的任务列表"}
    local nft_id = chainhelper:create_nft_asset(contract_base_info.owner,
                                                G_CONFIG.TASKS_WORLD_VIEW,
                                                cjson.encode(base_info), true,
                                                true)
    private_data.tasks_id = nft_id
end

-- 接受任务
function AcceptTask(task_id)
    _public_data = _public_data or _read_public_data()
    assert(_public_data[task_id] ~= nil, "#没有这个任务！#")
    if private_data.tasks_id == nil then _create_tasks_nft() end
    local t_config = _public_data[task_id]
    local contract_name = t_config[1]
    local func_name = t_config[2]
    local t_contract = import_contract(contract_name)
    t_contract.tasks_info = _get_tasks_info(nft_id)
    t_contract[func_name]("AcceptTask")
    chainhelper:nht_describe_change(nft_id, task_id, cjson.encode(
                                        t_contract.tasks_info[tasks_id]), false)
end

-- 完成任务
function Complete(task_id)
    _public_data = _public_data or _read_public_data()
    assert(_public_data[task_id] ~= nil, "#没有这个任务！#")
    local t_config = _public_data[task_id]
    local contract_name = t_config[1]
    local func_name = t_config[2]
    local t_contract = import_contract(contract_name)
    t_contract.tasks_info = _get_tasks_info(nft_id)
    t_contract[func_name]("Complete")
    chainhelper:nht_describe_change(nft_id, task_id, cjson.encode(
                                        t_contract.tasks_info[tasks_id]), false)
end

-- 接收并完成
function AcceptAndCompleteTask(task_id)
    _public_data = _public_data or _read_public_data()
    AcceptTask(task_id)
    Complete(task_id)
end

function update_config(task_id, contract_name, func_name)
    assert(chainhelper:is_owner(), "#没有权限#")
    read_list = {public_data = {}}
    chainhelper:read_chain()
    public_data[task_id] = {contract_name, func_name}
    write_list = {public_data = {}}
    chainhelper:write_chain()
end
