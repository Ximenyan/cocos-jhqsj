function TransferLockIn(symbol, amount) 
    assert(chainhelper:is_owner(),"#没有权限！#")
    chainhelper:adjust_lock_asset(symbol, amount)
end

function TransferReleaseOut(to, symbol, amount) 
    assert(chainhelper:is_owner(),"#没有权限！#")
    chainhelper:adjust_lock_asset(symbol, -amount)
    chainhelper:transfer_from_owner(to, amount, symbol, true)
end