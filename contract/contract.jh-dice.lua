--
-- Created by IntelliJ IDEA.
-- User: wang
-- Date: 20-10-12
-- Time: 下午2:46
-- To change this template use File | Settings | File Templates.
--

local function _get_data()
    read_list = {public_data={}, private_data={}} 
    chainhelper:read_chain()
end 

function ToBanker()
    _get_data()
   
end

function Dice()
end