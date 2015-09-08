class 'Wingsuit'

function Wingsuit:__init()
	
	self.default_speed = 51 -- 51 m/s default
	self.max_speed = 400 -- 300 m/s default
	self.min_speed = 0.5 -- 1 m/s default
	self.sink_speed = 8 -- 7 ms default (for realism mode)
	self.speed = self.default_speed
	
	self.realism = true
	
	self.toggle_action = Action.EquipBlackMarketBeacon
	
	self.actions = { -- Actions to block while flying
		Action.LookUp,
		Action.LookDown,
		Action.LookLeft,
		Action.LookRight
	}
	
	self.blacklist = { -- Disallow activating during these base states
		[AnimationState.SDead] = true,
		[AnimationState.SUnfoldParachuteHorizontal] = true,
		[AnimationState.SUnfoldParachuteVertical] = true,
		[AnimationState.SPullOpenParachuteVertical] = true
	}
	
	Events:Subscribe("KeyUp", self, self.KeyUp)
	Events:Subscribe("ModulesLoad", self, self.AddHelp)
	Events:Subscribe("ModuleUnload", self, self.RemoveHelp)
	Events:Subscribe("InputPoll", self, self.InputPoll)
end

function Wingsuit:InputPoll(args)
	if Input:GetValue(self.toggle_action) and not self.did_press_toggle_action then
		if self.is_active then
			self:Deactivate()
		else
			self:Activate()
		end
		self.did_press_toggle_action = true
	elseif not Input:GetValue(self.toggle_action) then
		self.did_press_toggle_action = false
	end
end

function Wingsuit:Activate()
	if not self.velocity_sub and LocalPlayer:GetState() == PlayerState.OnFoot then
		self.is_active = true
		local bs = LocalPlayer:GetBaseState()
		if self.blacklist[bs] then return end
		
		if not self.timer or self.timer:GetMilliseconds() > 500 then
			self.timer = Timer()
		elseif self.timer:GetMilliseconds() < 500 and not self.delay then
			self.timer = nil		
			if (not self.realism and (bs == AnimationState.SSkydive or bs == AnimationState.SParachute)) or (self.realism and bs == AnimationState.SSkydive) then
				self.speed = self.default_speed
				LocalPlayer:SetBaseState(AnimationState.SSkydive)
				self.velocity_sub = Events:Subscribe("Render", self, self.Velocity)
				self.camera_sub = Events:Subscribe("CalcView", self, self.Camera)
				self.input_sub = Events:Subscribe("InputPoll", self, self.InputBlock)
			elseif not self.realism then
				local timer = Timer()
				self.camera_sub = Events:Subscribe("CalcView", self, self.Camera)
				self.delay = Events:Subscribe("PreTick", self, function(self)
					LocalPlayer:SetLinearVelocity(LocalPlayer:GetAngle() * Vector3(0, 5, -5))
					if timer:GetMilliseconds() > 1000 then
						Events:Unsubscribe(self.delay)
						self.delay = nil
						self.speed = self.default_speed
						LocalPlayer:SetBaseState(AnimationState.SSkydive)
						self.velocity_sub = Events:Subscribe("Render", self, self.Velocity)
						self.input_sub = Events:Subscribe("InputPoll", self, self.InputBlock)
					end
				end)
			end
		end
	end
end

function Wingsuit:Deactivate()
	if self.velocity_sub then
		self.is_active = false
		if not self.timer or self.timer:GetMilliseconds() > 500 then
			self.timer = Timer()
		elseif self.timer:GetMilliseconds() < 500 then
			LocalPlayer:SetLinearVelocity(LocalPlayer:GetLinearVelocity() * 0)
			LocalPlayer:SetBaseState(AnimationState.SFall)
			self:Abort()
		end
	end
end

function Wingsuit:KeyUp(args)
	if args.key == VirtualKey.Shift and not self.is_active then
		self:Activate()
	elseif args.key == VirtualKey.Control and self.velocity_sub then
		self:Deactivate()
	end
end

function Wingsuit:Velocity()

	if LocalPlayer:GetBaseState() ~= AnimationState.SSkydive then
		self:Abort()
	end
	
	if self.realism then
	
		local speed = self.speed - math.sin(LocalPlayer:GetAngle().pitch) * 20
		LocalPlayer:SetLinearVelocity(LocalPlayer:GetAngle() * Vector3(0, 0, -speed) + Vector3(0, -self.sink_speed, 0))		
	
	else
	
		if Key:IsDown(VirtualKey.Shift) and self.speed < self.max_speed then
			self.speed = self.speed + 1
		elseif Key:IsDown(VirtualKey.Control) and self.speed > self.min_speed then
			self.speed = self.speed - 1
		end
			
		local speed = self.speed - math.sin(LocalPlayer:GetAngle().pitch) * 20
		LocalPlayer:SetLinearVelocity(LocalPlayer:GetAngle() * Vector3(0, 0, -speed))
		
	end
	
	local speed_string = string.format("%i km/h   %i m", LocalPlayer:GetLinearVelocity():Length() * 3.6, LocalPlayer:GetPosition().y - 200)
	local position = Vector2(0.5 * Render.Width - 0.5 * Render:GetTextWidth(speed_string, TextSize.Large), Render.Height - Render:GetTextHeight(speed_string, TextSize.Large))
	
	Render:DrawText(position, speed_string, Color.White, TextSize.Large)

end

function Wingsuit:InputBlock(args)
	for _, action in ipairs(self.actions) do
		Input:SetValue(action, 0)
	end
	
	if self.realism and Input:GetValue(Action.MoveBackward) > 0 and LocalPlayer:GetAngle().pitch > 0 then
		Input:SetValue(Action.MoveBackward, 0)
	end
end

function Wingsuit:Camera()
	Camera:SetPosition(LocalPlayer:GetPosition() + LocalPlayer:GetAngle() * Vector3(0, 2, 7))
	Camera:SetAngle(Angle.Slerp(Camera:GetAngle(), LocalPlayer:GetAngle(), 0.9))
end

function Wingsuit:Abort()
	Events:Unsubscribe(self.velocity_sub)
	Events:Unsubscribe(self.camera_sub)
	Events:Unsubscribe(self.input_sub)
	self.velocity_sub = nil
	self.camera_sub = nil
	self.input_sub = nil
end

function Wingsuit:AddHelp()

	if self.realism then
	
		Events:Fire("HelpAddItem",
			{
				name = "Wingsuit",
				text = 
					"The wingsuit allows you to fly around Panau unencumbered." .. 
					"\n\nTo activate, double-tap Shift or press d-pad down while sky-diving." ..
					"\nTo de-activate, double-tap Ctrl or press d-pad down."
			})	

	else

		Events:Fire("HelpAddItem",
			{
				name = "Wingsuit",
				text = 
					"The wingsuit allows you to fly around Panau unencumbered." .. 
					"\n\nTo activate, double-tap Shift. To de-activate, double-tap Ctrl." ..
					"\nWhile flying, hold Shift to speed up or Ctrl to slow down."
			})
			
	end

end

function Wingsuit:RemoveHelp()

    Events:Fire("HelpRemoveItem",
        {
            name = "Wingsuit"
        })

end

Wingsuit = Wingsuit()
