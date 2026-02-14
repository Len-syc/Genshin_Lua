-- FPV: First-Person View Toolkit (xLua) avatar
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

    local_offset  = CS.UnityEngine.Vector3(-0.045,0.1,0),

    fov           = 68,
    near_clip     = 0.02,

    disable_cinemachine = true,
    set_main_camera     = true,

    mouse_sensitivity = 2.5,
    mouse_pitch_limit = 85,
    mouse_invert_y    = false,
}

-------------------------------------------------------------
-- state
-------------------------------------------------------------
FPV.state = {
    entity_root = nil,
    old_cam     = nil,
    new_cam     = nil,
    avatar02    = nil,
    head_tf     = nil,
    pitch       = 0,
    base_local_rot = nil,
}

-------------------------------------------------------------
-- log
-------------------------------------------------------------
function FPV:_log(msg)
    local ok,f = pcall(io.open, self.cfg.log_path, "a")
    if ok and f then
        f:write(os.date("[%H:%M:%S] ")..tostring(msg).."\n")
        f:close()
    end
end

-------------------------------------------------------------
-- tools
-------------------------------------------------------------
function FPV:_find_child(root_go, path)
    if not root_go then return nil end
    local t = root_go.transform:Find(path)
    return t and t.gameObject or nil
end

function FPV:_safe_look_rotation(forward, up)
    if forward.sqrMagnitude < 1e-6 then forward = CS.UnityEngine.Vector3.forward end
    if up.sqrMagnitude < 1e-6 then up = CS.UnityEngine.Vector3.up end
    return CS.UnityEngine.Quaternion.LookRotation(forward.normalized, up.normalized)
end

-------------------------------------------------------------
-- locate cameras + avatar
-------------------------------------------------------------
function FPV:locate_roots()
    local er = CS.UnityEngine.GameObject.Find(self.cfg.use_entity)
    if not er then return false end
    self.state.entity_root = er

    local old = self:_find_child(er, self.cfg.old_cam_name)
    if not old then old = CS.UnityEngine.GameObject.Find(self.cfg.old_cam_name) end
    if not old then return false end
    self.state.old_cam = old
    return true
end

function FPV:prepare_new_camera()
    local nc = CS.UnityEngine.GameObject.Find(self.cfg.new_cam_name)
    if not nc then
        nc = CS.UnityEngine.Object.Instantiate(self.state.old_cam)
        nc.name = self.cfg.new_cam_name
    end
    self.state.new_cam = nc
end

-------------------------------------------------------------
-- resolve avatar + head
-------------------------------------------------------------
function FPV:resolve_avatar_nodes()
    local er = self.state.entity_root
    local avatarRoot = self:_find_child(er, "AvatarRoot")
    if not avatarRoot then return false end

    local tf01 = nil
    for i=0, avatarRoot.transform.childCount-1 do
        local c = avatarRoot.transform:GetChild(i)
        if c.gameObject.activeInHierarchy then tf01 = c break end
    end
    if not tf01 then return false end

    local offsetDummy = self:_find_child(tf01.gameObject, "OffsetDummy")
    if not offsetDummy then return false end

    local go02 = nil
    local od = offsetDummy.transform
    for i=0, od.childCount-1 do
        go02 = od:GetChild(i).gameObject
        break
    end
    if not go02 then return false end

    self.state.avatar02 = go02

    local headGO = self:_find_child(go02, self.cfg.head_path)
    if not headGO then return false end

    self.state.head_tf = headGO.transform
    return true
end

-------------------------------------------------------------
-- attach camera
-------------------------------------------------------------
function FPV:attach_to_head()
    local cam = self.state.new_cam
    local head = self.state.head_tf

    cam.transform:SetParent(head, false)
    cam.transform.localPosition = self.cfg.local_offset

    local bodyForward = self.state.avatar02.transform.forward
    cam.transform.rotation =
        self:_safe_look_rotation(bodyForward, CS.UnityEngine.Vector3.up)

    -- ⭐ 最终姿态后记录（防180翻转）
    self.state.base_local_rot = cam.transform.localRotation
    self.state.pitch = 0
end

-------------------------------------------------------------
-- camera params
-------------------------------------------------------------
function FPV:apply_camera_params()
    local camComp = self.state.new_cam:GetComponent(typeof(CS.UnityEngine.Camera))
    if camComp then
        camComp.fieldOfView   = self.cfg.fov
        camComp.nearClipPlane = self.cfg.near_clip
    end
end

-------------------------------------------------------------
-- main camera swap
-------------------------------------------------------------
function FPV:make_main_camera()
    local oldCam = self.state.old_cam
    local newCam = self.state.new_cam

    if oldCam then
        local al = oldCam:GetComponent(typeof(CS.UnityEngine.AudioListener))
        if al then al.enabled=false end
        oldCam.tag="Untagged"
    end

    local alNew = newCam:GetComponent(typeof(CS.UnityEngine.AudioListener))
    if alNew then alNew.enabled=true end

    newCam.tag="MainCamera"
end

-------------------------------------------------------------
-- mouse look
-------------------------------------------------------------
function FPV:_mouse_look_update()
    local cam = self.state.new_cam
    local avatar = self.state.avatar02
    if not cam or not avatar then return end

    local sens = self.cfg.mouse_sensitivity
    local mx = CS.UnityEngine.Input.GetAxis("Mouse X") * sens * 100 * CS.UnityEngine.Time.deltaTime
    local my = CS.UnityEngine.Input.GetAxis("Mouse Y") * sens * 100 * CS.UnityEngine.Time.deltaTime

    if self.cfg.mouse_invert_y then my=-my end

    -- yaw 身体旋转
    avatar.transform:Rotate(CS.UnityEngine.Vector3.up * mx, CS.UnityEngine.Space.World)

    -- pitch 相机俯仰
    self.state.pitch = self.state.pitch - my

    local limit = self.cfg.mouse_pitch_limit
    if self.state.pitch > limit then self.state.pitch = limit end
    if self.state.pitch < -limit then self.state.pitch = -limit end

    local pitchRot =
        CS.UnityEngine.Quaternion.AngleAxis(self.state.pitch, CS.UnityEngine.Vector3.right)

    cam.transform.localRotation = self.state.base_local_rot * pitchRot
end

-------------------------------------------------------------
-- start stop
-------------------------------------------------------------
function FPV.simple_start()
    if not FPV:locate_roots() then return false end
    FPV:prepare_new_camera()
    if not FPV:resolve_avatar_nodes() then return false end
    FPV:attach_to_head()
    FPV:apply_camera_params()
    FPV:make_ma