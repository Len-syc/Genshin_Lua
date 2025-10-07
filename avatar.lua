-- FPV: First-Person View 
local FPV = {}

-------------------------------------------------------------
-- cfg
-------------------------------------------------------------
FPV.cfg = {
    log_path      = "C:/Windy/log.txt",
    use_entity    = "EntityRoot",              
    old_cam_name  = "MainCamera(Clone)",
    new_cam_name  = "MainCamera(Clone)(Clone)",
    head_path     = table.concat({
        "Bip001","Bip001 Pelvis","Bip001 Spine","Bip001 Spine1",
        "Bip001 Spine2","Bip001 Neck","Bip001 Head"
    }, "/"),
    local_offset  = CS.UnityEngine.Vector3(-0.045,0.1,0), -- localPosition
    fov           = 68,
    near_clip     = 0.02,
    disable_cinemachine = true,                -- CinemachineBrain
    set_main_camera     = true,                -- MainCamere(Clone)
    log_verbose   = true,                      -- DetailLog
}

-------------------------------------------------------------
-- state
-------------------------------------------------------------
FPV.state = {
    entity_root = nil,
    old_cam     = nil,
    new_cam     = nil,
    avatar01    = nil,
    avatar02    = nil,
    head_tf     = nil,
}

-------------------------------------------------------------
-- Log
-------------------------------------------------------------
function FPV:_log_raw(msg)
    local ok,f = pcall(io.open, self.cfg.log_path, "a")
    if ok and f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ")..tostring(msg).."\n")
        f:close()
    end
end
function FPV:_fmt_v3(v) return string.format("(%.4f, %.4f, %.4f)", v.x, v.y, v.z) end
function FPV:_fmt_euler(q)
    local e = q.eulerAngles
    return string.format("(%.3f°, %.3f°, %.3f°)", e.x, e.y, e.z)
end
function FPV:_get_path(tf)
    if tf == nil then return "<nil>" end
    local parts, cur = {}, tf
    while cur ~= nil do table.insert(parts, 1, cur.gameObject.name); cur = cur.parent end
    return table.concat(parts, "/")
end
function FPV:_dump_tf(prefix, tf)
    if not self.cfg.log_verbose then return end
    if not tf then self:_log_raw(prefix.." [Transform=nil]"); return end
    self:_log_raw(prefix.." PATH: "..self:_get_path(tf))
    self:_log_raw(prefix.." WORLD pos="..self:_fmt_v3(tf.position).." rot="..self:_fmt_euler(tf.rotation)
        .." fwd="..self:_fmt_v3(tf.forward).." up="..self:_fmt_v3(tf.up))
    self:_log_raw(prefix.." LOCAL pos="..self:_fmt_v3(tf.localPosition).." rot="..self:_fmt_euler(tf.localRotation))
end

-------------------------------------------------------------
-- Tools
-------------------------------------------------------------
function FPV:_find_child_by_path(root_go, path)
    if not root_go or not path or path=="" then return nil end
    local t = root_go.transform:Find(path)
    return t and t.gameObject or nil
end

function FPV:_get_unique_active_child_tf(parent_tf)
    local active_tf = nil
    for i=0, parent_tf.childCount-1 do
        local c = parent_tf:GetChild(i)
        if c.gameObject.activeInHierarchy then
            if active_tf ~= nil then return nil end
            active_tf = c
        end
    end
    return active_tf
end

function FPV:_pick_active_clone_child_tf(parent_tf)
    local picked = nil
    for i=0, parent_tf.childCount-1 do
        local c = parent_tf:GetChild(i)
        local n = c.gameObject.name
        if c.gameObject.activeInHierarchy and n and n:sub(-7)=="(Clone)" then
            if picked ~= nil then return nil end
            picked = c
        end
    end
    return picked
end

function FPV:_strip_clone_suffix(name)
    if not name then return nil end
    if #name >= 7 and name:sub(-7)=="(Clone)" then
        return name:sub(1, #name-7)
    end
    return name
end

function FPV:_safe_look_rotation(forward, up)
    local f = forward
    if f.sqrMagnitude < 1e-8 then f = CS.UnityEngine.Vector3.forward end
    local u = up
    if u.sqrMagnitude < 1e-8 then u = CS.UnityEngine.Vector3.up end
    return CS.UnityEngine.Quaternion.LookRotation(f.normalized, u.normalized)
end

-------------------------------------------------------------
-- 定位根节点与相机
-------------------------------------------------------------
function FPV:locate_roots()
    self:_log_raw("S1: 定位 EntityRoot & OldCam")
    local er = CS.UnityEngine.GameObject.Find(self.cfg.use_entity) or CS.UnityEngine.GameObject.Find("EntiyRoot")
    if not er then self:_log_raw("S1 FAIL: 未找到 EntityRoot/EntiyRoot"); return false end
    self.state.entity_root = er
    self:_dump_tf("EntityRoot", er.transform)

    local old = self:_find_child_by_path(er, self.cfg.old_cam_name) or CS.UnityEngine.GameObject.Find(self.cfg.old_cam_name)
    if not old then self:_log_raw("S1 FAIL: 未找到 "..self.cfg.old_cam_name); return false end
    self.state.old_cam = old
    self:_dump_tf("OldCam(before)", old.transform)
    return true
end

function FPV:prepare_new_camera()
    self:_log_raw("S2: 准备新相机")
    local nc = CS.UnityEngine.GameObject.Find(self.cfg.new_cam_name)
    if not nc then
        nc = CS.UnityEngine.Object.Instantiate(self.state.old_cam)
        nc.name = self.cfg.new_cam_name
        self:_log_raw("S2: 克隆新相机 -> "..self.cfg.new_cam_name)
    else
        self:_log_raw("S2: 复用已存在新相机 -> "..self.cfg.new_cam_name)
    end
    self.state.new_cam = nc
    self:_dump_tf("NewCam(before)", nc.transform)
    return true
end

-------------------------------------------------------------
-- 解析 <01>/<02> 与 Head
-------------------------------------------------------------
function FPV:resolve_avatar_nodes()
    self:_log_raw("S3: 解析 <01>/<02>")
    local avatarRoot = self:_find_child_by_path(self.state.entity_root, "AvatarRoot")
    if not avatarRoot then self:_log_raw("S3 FAIL: 未找到 AvatarRoot"); return false end
    self:_dump_tf("AvatarRoot", avatarRoot.transform)

    local tf01 = self:_get_unique_active_child_tf(avatarRoot.transform)
    if not tf01 then tf01 = self:_pick_active_clone_child_tf(avatarRoot.transform) end
    if not tf01 then self:_log_raw("S3 FAIL: 无法确定 <01> 实例"); return false end
    self:_dump_tf("<01>", tf01)
    local go01 = tf01.gameObject
    self.state.avatar01 = go01

    local offsetDummy = self:_find_child_by_path(go01, "OffsetDummy")
    if not offsetDummy then self:_log_raw("S3 FAIL: 未找到 OffsetDummy"); return false end
    self:_dump_tf("OffsetDummy", offsetDummy.transform)

    local baseName = self:_strip_clone_suffix(go01.name)
    local go02 = (baseName and self:_find_child_by_path(offsetDummy, baseName)) or nil
    if not go02 then
        local od_tf = offsetDummy.transform
        for i=0, od_tf.childCount-1 do
            local c = od_tf:GetChild(i)
            if go02 ~= nil then go02 = nil break end
            go02 = c.gameObject
        end
    end
    if not go02 then self:_log_raw("S3 FAIL: 未能解析 <02> (base="..tostring(baseName)..")"); return false end
    self:_dump_tf("<02>", go02.transform)
    self.state.avatar02 = go02

    self:_log_raw("S4: 定位 Head")
    local headGO = self:_find_child_by_path(go02, self.cfg.head_path)
    if not headGO then self:_log_raw("S4 FAIL: 未找到 Head 路径: "..self.cfg.head_path); return false end
    self.state.head_tf = headGO.transform
    self:_dump_tf("Head", self.state.head_tf)
    return true
end

-------------------------------------------------------------
-- 挂接/朝向/参数/主相机切换
-------------------------------------------------------------
function FPV:attach_to_head()
    local cam = self.state.new_cam
    local head = self.state.head_tf
    self:_log_raw("S5: SetParent 到 Head")
    self:_dump_tf("NewCam(before parent)", cam.transform)
    self:_log_raw("parent(before)="..tostring(self:_get_path(cam.transform.parent)))
    cam.transform:SetParent(head, false)
    self:_log_raw("parent(after) ="..tostring(self:_get_path(cam.transform.parent)))
    self:_dump_tf("NewCam(after parent)", cam.transform)

    self:_log_raw("S6: 设置局部位置")
    self:_dump_tf("NewCam(before local pos)", cam.transform)
    cam.transform.localPosition = self.cfg.local_offset
    self:_dump_tf("NewCam(after local pos)", cam.transform)

    self:_log_raw("S7: 自动朝向（角色身体前向）")
    local bodyForward = self.state.avatar02.transform.forward
    local desiredRot  = self:_safe_look_rotation(bodyForward, CS.UnityEngine.Vector3.up)
    local beforeRot   = cam.transform.rotation
    cam.transform.rotation = desiredRot
    self:_log_raw("S7 Cam world rot: "..self:_fmt_euler(beforeRot).." -> "..self:_fmt_euler(cam.transform.rotation))
    self:_dump_tf("NewCam(after world rot)", cam.transform)
end

function FPV:apply_camera_params()
    self:_log_raw("S8: 相机参数 & 组件")
    local camComp = self.state.new_cam:GetComponent(typeof(CS.UnityEngine.Camera))
    if camComp then
        camComp.fieldOfView   = self.cfg.fov
        camComp.nearClipPlane = self.cfg.near_clip
        self:_log_raw("Camera params: FOV="..tostring(self.cfg.fov).." Near="..tostring(self.cfg.near_clip))
    end
    if self.cfg.disable_cinemachine then
        local brain = self.state.new_cam:GetComponent(typeof(CS.Cinemachine.CinemachineBrain))
        if brain ~= nil then
            local was = brain.enabled
            brain.enabled = false
            self:_log_raw("CinemachineBrain: "..tostring(was).." -> false")
        else
            self:_log_raw("CinemachineBrain: not found")
        end
    end
end

function FPV:make_main_camera()
    if not self.cfg.set_main_camera then return end
    local oldCam = self.state.old_cam
    local newCam = self.state.new_cam
    if oldCam then
        local alOld = oldCam:GetComponent(typeof(CS.UnityEngine.AudioListener))
        if alOld then local w=alOld.enabled; alOld.enabled=false; self:_log_raw("OldCam AudioListener: "..tostring(w).." -> false") end
        local tagWas = oldCam.tag; oldCam.tag="Untagged"; self:_log_raw("OldCam tag: '"..tagWas.."' -> 'Untagged'")
    end
    local alNew = newCam:GetComponent(typeof(CS.UnityEngine.AudioListener))
    if alNew then local w=alNew.enabled; alNew.enabled=true; self:_log_raw("NewCam AudioListener: "..tostring(w).." -> true") end
    local tagWasN = newCam.tag; newCam.tag="MainCamera"; newCam:SetActive(true); self:_log_raw("NewCam tag: '"..tagWasN.."' -> 'MainCamera'")
end

-------------------------------------------------------------
-- -- 清理
-- -------------------------------------------------------------
-- function FPV:teardown()
--     if self.state and self.state.new_cam then
--         self:_log_raw("Teardown: 还原旧相机标签/AudioListener 并删除新相机")
--         local oldCam = self.state.old_cam
--         if oldCam then
--             oldCam.tag = "MainCamera"
--             local alOld = oldCam:GetComponent(typeof(CS.UnityEngine.AudioListener))
--             if alOld then alOld.enabled = true end
--         end
--         CS.UnityEngine.Object.Destroy(self.state.new_cam)
--     end
-- end

-------------------------------------------------------------
-------------------------------------------------------------
function FPV.simple_start(opts)
    if opts then for k,v in pairs(opts) do FPV.cfg[k]=v end end
    FPV:_log_raw("==== [START] FPV.simple_start ====")
    if not FPV:locate_roots()        then return false end
    if not FPV:prepare_new_camera()  then return false end
    if not FPV:resolve_avatar_nodes() then return false end
    FPV:attach_to_head()
    FPV:apply_camera_params()
    FPV:make_main_camera()
    FPV:_log_raw("==== [DONE] -> first person ====")
    local okf,f = pcall(io.open, FPV.cfg.log_path, "a")
    if okf and f then f:write(os.date("[%Y-%m-%d %H:%M:%S] ").."first person\n"); f:close() end
    return true
end

-- -- 关闭（回滚）
-- function FPV.simple_stop()
--     FPV:teardown()
--     FPV:_log_raw("==== [STOP] FPV.simple_stop ====")
-- end

-------------------------------------------------------------
-------------------------------------------------------------
local function _ensure_log_dir(path)
    local dir = path:match("^(.*)/[^/]+$") or path:match("^(.*)\\[^\\]+$")
    if dir and CS.System and CS.System.IO and CS.System.IO.Directory then
        CS.System.IO.Directory.CreateDirectory(dir)
    end
end

if not FPV.state._auto_started then
    FPV.state._auto_started = true
    _ensure_log_dir(FPV.cfg.log_path)
    local ok, err = pcall(function()
        FPV:_log_raw("==== [AUTO] FPV module loaded, autostart begin ====")
        FPV.simple_start()
        FPV:_log_raw("==== [AUTO] FPV autostart done ====")
    end)
    if not ok then
        FPV:_log_raw("❌ [AUTO] FPV autostart failed: "..tostring(err))
    end
end

return FPV
