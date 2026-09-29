-- The runner inserts the unmodified library body into each fresh mock runtime.
local function Signal()
	local Listeners = {}
	return {
		Connect = function(_,Callback)
			table.insert(Listeners,Callback)
			return {Disconnect = function()
				local Index = table.find(Listeners,Callback)
				if Index then table.remove(Listeners,Index) end
			end}
		end,
		Fire = function(_, ...)
			for _,Callback in Listeners do Callback(...) end
		end,
	}
end

local function NewRuntime()
	local function EnumItem(Name)
		return {Name = Name,IsEnumItem = true}
	end
	local Enum = {KeyCode = {},UserInputType = {}}
	for _,Name in {"Unknown","LeftShift","DPadDown","X","Y","A","B","C","ButtonL3"} do
		Enum.KeyCode[Name] = EnumItem(Name)
	end
	for _,Name in {"Keyboard","MouseButton1","MouseButton2","MouseWheel","MouseMovement","Gamepad1","Touch"} do
		Enum.UserInputType[Name] = EnumItem(Name)
	end
	local UserInputService = {LastInputType = Enum.UserInputType.Keyboard}
	function UserInputService:GetLastInputType() return self.LastInputType end
	for _,Name in {"InputBegan","InputEnded","TouchTap","TouchPan","TouchLongPress","TouchSwipe","TouchPinch","TouchRotate"} do
		UserInputService[Name] = Signal()
	end
	local RunService = {Heartbeat = Signal()}
	local game = {GetService = function(_,Name)
		return if Name == "UserInputService" then UserInputService else RunService
	end}
	local task = {delay = function() end}
	local typeof = function(Value)
		return if type(Value) == "table" and Value.IsEnumItem then "EnumItem" else type(Value)
	end
	local function LoadLibrary()
-- LIBRARY_SOURCE
	end
	local Library = LoadLibrary()
	local Button = {InputBegan = Signal(),InputEnded = Signal()}
	local Definitions = {
		Gameplay = {
			Run = {
				PC = {Input = Enum.KeyCode.LeftShift,Priority = 1},
				Gamepad = {Input = Enum.KeyCode.DPadDown,Priority = 2,Toggle = true},
				Touch = {Input = Library.Touch.Tap,Priority = 3},
				Button = {Button = Button,Toggle = false,Priority = 4},
			},
			Run2 = {PC = {Input = Enum.KeyCode.LeftShift,Priority = 2}},
			Combo = {
				PC = {Input = {Enum.KeyCode.A,Enum.KeyCode.B},Priority = 5,Combo = {
					Query = Library.Combos.StrictOrdered,HoldInputs = {},GracePeriod = 1,
				}},
				Gamepad = {Input = Enum.KeyCode.ButtonL3,Priority = 1},
			},
			ButtonOnly = {Button = {Button = {InputBegan = Signal(),InputEnded = Signal()},Toggle = false,Priority = 1}},
		},
	}
	Library.CreateContexts(Definitions)
	local function Press(KeyCode,Device)
		UserInputService.LastInputType = Enum.UserInputType[Device or "Keyboard"]
		UserInputService.InputBegan:Fire({KeyCode = KeyCode,UserInputType = UserInputService.LastInputType},false)
	end
	return Library,Enum,UserInputService,Definitions.Gameplay,Button,Press
end

local Count = 0
local function Test(Name,Callback)
	Callback()
	Count += 1
	print("PASS "..Name)
end

Test("explicit device changes only PC even while gamepad is active",function()
	local Lib,E,UIS = NewRuntime()
	UIS.LastInputType = E.UserInputType.Gamepad1
	Lib.SetActionKeybind("Run",E.KeyCode.X,"PC")
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.X)
	assert(Lib.GetActionKeybind("Run","Gamepad") == E.KeyCode.DPadDown)
	assert(Lib.GetActionKeybind("Run","Touch") == Lib.Touch.Tap)
end)

Test("omitted device follows current device deterministically",function()
	local Lib,E,UIS = NewRuntime()
	Lib.SetActionKeybind("Run",E.KeyCode.X)
	assert(Lib.GetActionKeybind("Run") == E.KeyCode.X)
	UIS.LastInputType = E.UserInputType.Gamepad1
	Lib.SetActionKeybind("Run",E.KeyCode.Y)
	assert(Lib.GetActionKeybind("Run") == E.KeyCode.Y)
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.X)
end)

Test("save includes all input devices and ordered combos, excludes GUI buttons",function()
	local Lib,E = NewRuntime()
	local Saved = Lib.GetCustomKeybinds()
	assert(Saved.Run.PC == E.KeyCode.LeftShift)
	assert(Saved.Run.Gamepad == E.KeyCode.DPadDown)
	assert(Saved.Run.Touch == Lib.Touch.Tap)
	assert(Saved.Run.Button == nil and Saved.ButtonOnly == nil)
	assert(Saved.Combo.PC[1] == E.KeyCode.A and Saved.Combo.PC[2] == E.KeyCode.B)
end)

Test("save/load round trip restores every device independent of active device",function()
	local Lib,E,UIS = NewRuntime()
	local Saved = Lib.GetCustomKeybinds()
	Lib.SetActionKeybind("Run",E.KeyCode.X,"PC")
	Lib.SetActionKeybind("Run",E.KeyCode.Y,"Gamepad")
	Lib.SetActionKeybind("Run",Lib.Touch.Swipe,"Touch")
	UIS.LastInputType = E.UserInputType.Touch
	Lib.LoadCustomKeybinds(Saved)
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.LeftShift)
	assert(Lib.GetActionKeybind("Run","Gamepad") == E.KeyCode.DPadDown)
	assert(Lib.GetActionKeybind("Run","Touch") == Lib.Touch.Tap)
end)

Test("partial loads preserve devices that are not in the save",function()
	local Lib,E = NewRuntime()
	Lib.LoadCustomKeybinds({Run = {Gamepad = E.KeyCode.Y}})
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.LeftShift)
	assert(Lib.GetActionKeybind("Run","Gamepad") == E.KeyCode.Y)
	assert(Lib.GetActionKeybind("Run","Touch") == Lib.Touch.Tap)
end)

Test("legacy flat saves target only the current device",function()
	local Lib,E = NewRuntime()
	Lib.LoadCustomKeybinds({Run = E.KeyCode.X})
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.X)
	assert(Lib.GetActionKeybind("Run","Gamepad") == E.KeyCode.DPadDown)
	Lib.LoadCustomKeybinds({Combo = {E.KeyCode.B,E.KeyCode.A}})
	assert(Lib.GetActionKeybind("Combo","PC")[1] == E.KeyCode.B)
end)

Test("rebinding preserves other actions sharing an input and priorities",function()
	local Lib,E,_,_,_,Press = NewRuntime()
	local Run,Run2 = 0,0
	Lib.BindToActionActivated("Run",function() Run += 1 end)
	Lib.BindToActionActivated("Run2",function() Run2 += 1 end)
	Lib.SetActionKeybind("Run",E.KeyCode.X,"PC")
	Press(E.KeyCode.LeftShift)
	Press(E.KeyCode.X)
	assert(Run == 1 and Run2 == 1)
	Lib.SetActionKeybind("Run",E.KeyCode.LeftShift,"PC")
	Press(E.KeyCode.LeftShift)
	assert(Run == 1 and Run2 == 2)
end)

Test("same action and same input across devices stay independent",function()
	local Lib,E,_,_,_,Press = NewRuntime()
	local Run = 0
	Lib.BindToActionActivated("Run",function() Run += 1 end)
	Lib.SetActionKeybind("Run",E.KeyCode.X,"PC")
	Lib.SetActionKeybind("Run",E.KeyCode.X,"Gamepad")
	Lib.SetActionKeybind("Run",E.KeyCode.Y,"PC")
	Press(E.KeyCode.X,"Gamepad1")
	assert(Run == 1)
	assert(Lib.GetActionKeybind("Run","Gamepad") == E.KeyCode.X)
end)

Test("getters and setters do not expose mutable combo input arrays",function()
	local Lib,E = NewRuntime()
	local Saved = Lib.GetCustomKeybinds()
	Saved.Combo.PC[1] = E.KeyCode.X
	local Got = Lib.GetActionKeybind("Combo","PC")
	Got[1] = E.KeyCode.Y
	assert(Lib.GetActionKeybind("Combo","PC")[1] == E.KeyCode.A)
	local Inputs = {E.KeyCode.B,E.KeyCode.C}
	Lib.SetActionKeybind("Combo",Inputs,"PC")
	Inputs[1] = E.KeyCode.X
	assert(Lib.GetActionKeybind("Combo","PC")[1] == E.KeyCode.B)
end)

Test("input dispatch compares priorities only for the active device",function()
	local Lib,E,_,_,_,Press = NewRuntime()
	local Run,Run2 = 0,0
	Lib.BindToActionActivated("Run",function() Run += 1 end)
	Lib.BindToActionActivated("Run2",function() Run2 += 1 end)
	Lib.SetActionKeybind("Run",E.KeyCode.X,"Gamepad")
	Lib.SetActionKeybind("Run2",E.KeyCode.X,"PC")
	Press(E.KeyCode.X)
	assert(Run == 0 and Run2 == 1)
	Press(E.KeyCode.X,"Gamepad1")
	assert(Run == 1 and Run2 == 1)
end)

Test("combo rebind removes old dispatch entries and retains ordered detection",function()
	local Lib,E,_,_,_,Press = NewRuntime()
	local Hits = 0
	Lib.BindToActionActivated("Combo",function() Hits += 1 end)
	Lib.LoadCustomKeybinds({Combo = {PC = {E.KeyCode.B,E.KeyCode.C}}})
	Press(E.KeyCode.B)
	Press(E.KeyCode.A) -- Would consume the combo if the old A entry were left behind.
	Press(E.KeyCode.C)
	assert(Hits == 0)
	Press(E.KeyCode.B)
	Press(E.KeyCode.C)
	assert(Hits == 1)
end)

Test("single input replaces combo and updates callback dispatch",function()
	local Lib,E,_,Actions,_,Press = NewRuntime()
	local Hits = 0
	Lib.BindToActionActivated("Combo",function() Hits += 1 end)
	Lib.SetActionKeybind("Combo",E.KeyCode.X,"PC")
	assert(Actions.Combo.PC.Combo == nil)
	Press(E.KeyCode.A)
	Press(E.KeyCode.B)
	assert(Hits == 0)
	Press(E.KeyCode.X)
	assert(Hits == 1)
end)

Test("repeated reset restores all inputs, combos, and dispatch",function()
	local Lib,E,_,Actions,_,Press = NewRuntime()
	local Hits = 0
	Lib.BindToActionActivated("Combo",function() Hits += 1 end)
	for _ = 1,3 do
		Lib.SetActionKeybind("Run",E.KeyCode.X,"PC")
		Lib.SetActionKeybind("Run",E.KeyCode.Y,"Gamepad")
		Lib.SetActionKeybind("Run",Lib.Touch.Swipe,"Touch")
		Lib.SetActionKeybind("Combo",E.KeyCode.X,"PC")
		Lib.ResetActionKeybinds()
		assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.LeftShift)
		assert(Lib.GetActionKeybind("Run","Gamepad") == E.KeyCode.DPadDown)
		assert(Lib.GetActionKeybind("Run","Touch") == Lib.Touch.Tap)
		assert(Actions.Combo.PC.Combo ~= nil)
		assert(Lib.GetActionKeybind("Combo","PC")[1] == E.KeyCode.A)
	end
	Press(E.KeyCode.A)
	Press(E.KeyCode.B)
	assert(Hits == 1)
end)

Test("combo API replacements keep metadata and other devices intact",function()
	local Lib,E,_,_,_,Press = NewRuntime()
	local Hits = 0
	Lib.BindToActionActivated("Combo",function() Hits += 1 end)
	Lib.SetActionCombo("Combo",{E.KeyCode.B,E.KeyCode.C},{Query = Lib.Combos.StrictOrdered,HoldInputs = {},GracePeriod = 1})
	assert(Lib.GetCustomKeybinds().Combo.PC[2] == E.KeyCode.C)
	Lib.ResetActionCombo("Combo",E.KeyCode.X)
	Press(E.KeyCode.B)
	Press(E.KeyCode.C)
	assert(Hits == 0)
	Press(E.KeyCode.X)
	assert(Hits == 1)
	assert(Lib.GetActionKeybind("Combo","Gamepad") == E.KeyCode.ButtonL3)
end)

Test("GUI button remains connected after rebind/load/reset",function()
	local Lib,E,_,_,Button = NewRuntime()
	local Hits = 0
	Lib.BindToActionActivated("Run",function(_,Data)
		assert(Data.Device == "Button")
		Hits += 1
	end)
	local Saved = Lib.GetCustomKeybinds()
	Lib.SetActionKeybind("Run",E.KeyCode.X,"PC")
	Lib.LoadCustomKeybinds(Saved)
	Lib.ResetActionKeybinds()
	Button.InputBegan:Fire({UserInputType = E.UserInputType.MouseButton1})
	assert(Hits == 1)
end)

Test("touch rebind dispatches the new gesture without changing keyboard controls",function()
	local Lib,E,UIS = NewRuntime()
	local Hits = 0
	Lib.BindToActionActivated("Run",function() Hits += 1 end)
	Lib.LoadCustomKeybinds({Run = {Touch = Lib.Touch.Swipe}})
	UIS.LastInputType = E.UserInputType.Touch
	UIS.TouchTap:Fire({},false)
	assert(Hits == 0)
	UIS.TouchSwipe:Fire({},1,false)
	assert(Hits == 1)
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.LeftShift)
end)

Test("missing and unsupported devices fail without changing bindings",function()
	local Lib,E,UIS = NewRuntime()
	assert(Lib.GetActionKeybind("Missing","PC") == nil)
	assert(Lib.GetActionKeybind("Run","Button") == nil)
	assert(not pcall(Lib.SetActionKeybind,"Run",E.KeyCode.X,"Button"))
	assert(not pcall(Lib.SetActionKeybind,"Run2",E.KeyCode.X,"Touch"))
	assert(not pcall(Lib.SetActionKeybind,"Run",{},"PC"))
	UIS.LastInputType = {Name = "None"}
	assert(not pcall(Lib.SetActionKeybind,"Run",E.KeyCode.X))
	assert(Lib.GetActionKeybind("Run","PC") == E.KeyCode.LeftShift)
end)

print(tostring(Count).." tests passed")
