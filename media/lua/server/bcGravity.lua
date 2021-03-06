-- require "TimedActions/ISDestroyStuffAction.lua"
require "BuildingObjects/ISWoodenFloor.lua"
require "BuildingObjects/ISWoodenStairs.lua"
require "bcUtils"

bcGravity = {};
bcGravity.radius = 2;
bcGravity.preventLoop = false;
bcGravity.squares = {};

bcGravity.ISWSSetInfo = ISWoodenStairs.setInfo; -- {{{
ISWoodenStairs.setInfo = function(self, square, level, north, sprite, luaobject)
	bcGravity.ISWSSetInfo(self, square, level, north, sprite, luaobject);
	local _x = square:getX();
	local _y = square:getY();
	local _z = square:getZ();
	local xb = _x;
	local yb = _y;

	-- might be a pretty broad check, but this should really be in Java...
	for xb=_x-2,_x+2 do
		for yb=_y-2,_y+2 do
			for _z = square:getZ(),0,-1 do
				local sq = getCell():getGridSquare(xb, yb ,_z);
				if sq then
					for i = sq:getObjects():size(),1,-1 do
						local obj = sq:getObjects():get(i-1);
						local sprite = obj:getSprite();
						if sprite then
							local name = sprite:getName();
							if name == self.pillar or name == self.pillarNorth or name == self.sprite3 or name == self.northSprite3 then
								sprite:getProperties():Set(IsoFlagType.cutN);
							end
						end
					end
				end
			end
		end
	end
end -- }}}

bcGravity.ISWFisValid = ISWoodenFloor.isValid; -- {{{
ISWoodenFloor.isValid = function(self, square)
	local _x = square:getX();
	local _y = square:getY();
	local _z = square:getZ();

	if _z < 1 then
		return bcGravity.ISWFisValid(self, square);
	end

	if not bcGravity.ISWFisValid(self, square) then return false end;
	for x=_x-3,_x+3 do
		for y=_y-3,_y+3 do
			if bcGravity.sqHasWall(getCell():getGridSquare(x, y, _z-1)) then
				return bcGravity.ISWFisValid(self, square);
			end
		end
	end
	return false;
end
-- }}}

bcGravity.sqHasWall = function(sq)--{{{
	if not sq then return false; end
	if sq:getWall(false) then return true; end
	if sq:getWall(true)  then return true; end
	return false;
end
--}}}
bcGravity.destroyObject = function(obj) -- {{{
	-- CopyPasted from ISDestroyStuffAction.perform

	-- we add the items contained inside the item we destroyed to put them randomly on the ground
	for i=1,obj:getContainerCount() do
		local container = obj:getContainerByIndex(i-1)
		local sq = obj:getSquare();
		for j=1,container:getItems():size() do
			local item = sq:AddWorldInventoryItem(container:getItems():get(j-1), 0.0, 0.0, 0.0)
			bcGravity.dropItemsDown(sq, item);
			local args = {};
			args.x = sq:getX();
			args.y = sq:getY();
			args.z = sq:getZ();
			sendServerCommand("bcGravity", "dropItemsDown", args);
		end
	end

	-- destroy window if wall is destroyed
	if obj:getSquare():getWall(false) == obj or obj:getSquare():getWall(true) == obj then
		for i=0,obj:getSquare():getSpecialObjects():size()-1 do
			local o = obj:getSquare():getSpecialObjects():get(i)
			if instanceof(o, 'IsoWindow') and (o:getNorth() == obj:getProperties():Is(IsoFlagType.cutN)) then
				obj = o
				break
			end
		end
	end

	-- destroy barricades if door is destroyed
	if instanceof(obj, 'IsoDoor') or (instanceof(obj, 'IsoThumpable') and obj:isDoor()) then
		local barricade1 = obj:getBarricadeOnSameSquare()
		local barricade2 = obj:getBarricadeOnOppositeSquare()
		if barricade1 then
			barricade1:getSquare():transmitRemoveItemFromSquare(barricade1)
			barricade1:getSquare():RemoveTileObject(barricade1)
		end
		if barricade2 then
			barricade2:getSquare():transmitRemoveItemFromSquare(barricade2)
			barricade2:getSquare():RemoveTileObject(barricade2)
		end
	end

	-- remove curtains if window is destroyed
	if instanceof(obj, 'IsoWindow') and obj:HasCurtains() then
		local curtains = obj:HasCurtains()
		curtains:getSquare():transmitRemoveItemFromSquare(curtains)
		curtains:getSquare():RemoveTileObject(curtains)
		local sheet = InventoryItemFactory.CreateItem("Base.Sheet")
		obj:getSquare():AddWorldInventoryItem(sheet, 0, 0, 0)
	end
	-- remove sheet rope too
	if instanceof(obj, 'IsoWindow') or instanceof(obj, 'IsoThumpable') then
		obj:removeSheetRope(nil);
	end

	if instanceof(obj, 'IsoCurtain') and obj:getSquare() then
		local sheet = InventoryItemFactory.CreateItem("Base.Sheet")
		obj:getSquare():AddWorldInventoryItem(sheet, 0, 0, 0)
	end

	-- Hack, should we do triggerEvent("OnDestroyIsoThumpable") here?
	-- When you destroy with an axe, you get "need:XXX" materials back.
	RainCollectorBarrel.OnDestroyIsoThumpable(obj, nil)
	TrapSystem.OnDestroyIsoThumpable(obj, nil)

	-- Destroy all 3 stair objects (and sometimes the floor at the top)
	local stairObjects = buildUtil.getStairObjects(obj)
	if #stairObjects > 0 then
		for i=1,#stairObjects do
			stairObjects[i]:getSquare():transmitRemoveItemFromSquare(stairObjects[i])
			stairObjects[i]:getSquare():RemoveTileObject(stairObjects[i])
		end
	else
		obj:getSquare():transmitRemoveItemFromSquare(obj)
		obj:getSquare():RemoveTileObject(obj)
	end
end
-- }}}

bcGravity.dropStaticMovingItemsDown = function(sq, item)--{{{
	local id = -1;
	if instanceof(item, "InventoryItem") then
		id = item:getID();
		item = item:getWorldItem();
	end
	if not item then return end;

	sq:transmitRemoveItemFromSquare(item:getItem());
	sq:RemoveTileObject(item);
	sq:getStaticMovingObjects():remove(item);
	sq:getCell():render();
	for nz=sq:getZ(),0,-1 do
		local nsq = getCell():getGridSquare(sq:getX(), sq:getY(), nz);
		if nz == 0 or (nsq and nsq:getFloor()) then
			nsq:AddWorldInventoryItem(item:getItem(), 0.0 , 0.0, 0.0);
			item:transmitCompleteItemToClients();
			return;
		end
	end
end
--}}}

bcGravity.dropItemsDown = function(sq, item)--{{{
	-- print("bcGravity.dropItemsDown: dropping on "..sq:getX().."x"..sq:getY().."x"..sq:getZ());
	local id = -1;
	if instanceof(item, "InventoryItem") then
		id = item:getID();
		item = item:getWorldItem();
	end
	if not item then return end;

	sq:transmitRemoveItemFromSquare(item);
	sq:RemoveTileObject(item);
	sq:getWorldObjects():remove(item);
	sq:getSpecialObjects():remove(item);
	sq:getObjects():remove(item);
	for nz=sq:getZ(),0,-1 do
		local nsq = getCell():getGridSquare(sq:getX(), sq:getY(), nz);
		if nz == 0 or (nsq and nsq:getFloor()) then
			nsq:AddWorldInventoryItem(item:getItem(), 0.0 , 0.0, 0.0);
			item:transmitCompleteItemToClients();
			-- print("bcGravity.dropItemsDown: dropped "..tostring(item).." to level "..tostring(nz));
			return;
		end
	end
end
--}}}
bcGravity.itsTheLaw = function(_x, _y, _z)--{{{
	-- TODO differentiate between player-built and prefabbed structures
	if _z < 1 then return; end

	local x;
	local y;
	local sq;
	local destroyedSomething = false;
	local droppedSomething = false;
	local additionalSquares = {};

	sq = getCell():getGridSquare(_x, _y, _z);
	if not sq then return end;

	for x=_x-bcGravity.radius,_x+bcGravity.radius do
		for y=_y-bcGravity.radius,_y+bcGravity.radius do
			if bcGravity.sqHasWall(getCell():getGridSquare(x, y, _z-1)) then
				return;
			end
		end
	end

	for i = sq:getObjects():size(),1,-1 do
		local obj = sq:getObjects():get(i-1);
		-- local isFloor = obj:getSprite():getProperties():Is(IsoFlagType.solidFloor);

		if instanceof(obj, "IsoWorldInventoryObject") then
			bcGravity.dropItemsDown(sq, obj);
			droppedSomething = true;
		else -- not an IsoWorldInventoryObject
			destroyedSomething = true;
			bcGravity.destroyObject(obj);
			sq:playSound("breakdoor", true);
		end
		if destroyedSomething and not bcGravity.sqHasWall(sq) then
			table.insert(additionalSquares, getCell():getGridSquare(_x, _y, _z));
		end
	end
	if droppedSomething then
		local args = {};
		args.x = sq:getX();
		args.y = sq:getY();
		args.z = sq:getZ();
		sendServerCommand("bcGravity", "dropItemsDown", args);
	end

	droppedSomething = false;
	for i = sq:getStaticMovingObjects():size(),1,-1 do
		local obj = sq:getStaticMovingObjects():get(i-1);
		bcGravity.dropStaticMovingItemsDown(sq, obj);
		droppedSomething = true;
	end
	if droppedSomething then
		local args = {};
		args.x = sq:getX();
		args.y = sq:getY();
		args.z = sq:getZ();
		sendServerCommand("bcGravity", "dropStaticMovingItemsDown", args);
	end

	if destroyedSomething then
		local moving = getCell():getGridSquare(_x, _y, _z-1);
		if not moving then return end
		moving = moving:getMovingObjects();
		-- print("bcGravity.itsTheLaw: # of entities: "..tostring(moving:size()));
		for i = moving:size(),1,-1 do
			local ent = moving:get(i-1);
			if ent then
				-- print("bcGravity.itsTheLaw: Found entity: "..tostring(ent));
				local hits = 2+ZombRand(3);
				local hploss = 15 + ZombRand(15);
				for i=0,hits do
					if instanceof(ent, "IsoZombie") then
						if ZombRand(100) < 80 then
							ent:Kill(nil);
						else
							local health = ent:getHealth() - ((2 + ZombRand(10)) / 10.0);
							if health <= 0 then
								ent:Kill(nil);
							else
								ent:setHealth(health);
								-- TODO ent:changeState(StaggerBackState.instance());
							end
						end
					else
						ent:Hit(InventoryItemFactory.CreateItem("Base.Axe"), getCell():getFakeZombieForHit(), math.ceil(hploss / hits), false, 1.0F);
					end
				end
			end
		end
	end

	for _,sq in pairs(additionalSquares) do
		for x=sq:getX()-bcGravity.radius,sq:getX()+bcGravity.radius do
			for y=sq:getY()-bcGravity.radius,sq:getY()+bcGravity.radius do
				bcGravity.checkSquare(x, y, sq:getZ(), true);
				if sq:getZ() < 7 then
					bcGravity.checkSquare(x, y, sq:getZ()+1, true);
				end
			end
		end
	end
end
--}}}

bcGravity.obeyGravity = function()--{{{
	local done = false;
	local x;
	local y;
	local z;

	while not done do
		done = true;
		local newSquares = bcUtils.cloneTable(bcGravity.squares);
		for x,_ in pairs(newSquares) do
			for y,_ in pairs(newSquares[x]) do
				for z,_ in pairs(newSquares[x][y]) do
					if not bcGravity.squares[x][y][z] then
						bcGravity.itsTheLaw(x, y, z);
						bcGravity.squares[x][y][z] = true;
						done = false;
					end
				end
			end
		end
	end
end
--}}}
bcGravity.checkSquare = function(x, y, z, force)--{{{
	if not bcGravity.squares[x] then
		bcGravity.squares[x] = {};
	end
	if not bcGravity.squares[x][y] then
		bcGravity.squares[x][y] = {};
	end
	if bcGravity.squares[x][y][z] and not force then
		return;
	end

	bcGravity.squares[x][y][z] = false;
end
--}}}

bcGravity.ReceiveFromServer = function(_module, _command, _args) -- {{{
	-- print("bcGravity.ReceiveFromServer: "..tostring(_module)..", "..tostring(_command)..", "..tostring(_args));

	if _module ~= 'bcGravity' then return end

	local sq = getCell():getGridSquare(_args.x, _args.y, _args.z);
	if not sq then return end
	local objs = sq:getObjects();

	for i = objs:size(),1,-1 do
		local item = objs:get(i-1);
		local id = -1;
		if instanceof(item, "InventoryItem") then
			id = item:getID();
			item = item:getWorldItem();
		end
		if item then
			sq:RemoveTileObject(item);
			if _command == 'dropItemsDown' then
				sq:getWorldObjects():remove(item);
				sq:getSpecialObjects():remove(item);
				sq:getObjects():remove(item);
			end
			if _command == 'dropStaticMovingItemsDown' then
				sq:getStaticMovingObjects():remove(item);
			end
		end
	end
	sq:getCell():render();
end -- }}}

bcGravity.ReceiveFromClient = function(_module, _command, _player, _args) -- {{{
	-- print("bcGravity.ReceiveFromClient: "..tostring(_module)..", "..tostring(_command)..", "..tostring(_player)..", "..tostring(_args));

	if _module ~= 'bcGravity' then return end
	if _command ~= 'OnTileRemoved' then return end

	local sq = getCell():getGridSquare(_args.x, _args.y, _args.z);
	if not sq then return end;

	if bcGravity.preventLoop then return end
	bcGravity.preventLoop = true;

	bcGravity.squares = {};

	if _args.hadWall and sq:getZ() < 7 then
		for x=sq:getX()-bcGravity.radius,sq:getX()+bcGravity.radius do
			for y=sq:getY()-bcGravity.radius,sq:getY()+bcGravity.radius do
				bcGravity.checkSquare(x, y, sq:getZ()+1);
			end
		end
	end

	for x=sq:getX()-bcGravity.radius,sq:getX()+bcGravity.radius do
		for y=sq:getY()-bcGravity.radius,sq:getY()+bcGravity.radius do
			bcGravity.checkSquare(x, y, sq:getZ());
		end
	end

	bcGravity.obeyGravity();

	bcGravity.preventLoop = false;
end -- }}}

bcGravity.OnTileRemoved = function(obj) -- {{{
	if bcGravity.preventLoop then return end
	bcGravity.preventLoop = true;

	local sq = obj:getSquare();
	if not sq then
		print("error: obj:getSquare() is nil!");
		bcGravity.preventLoop = false;
		return;
	end

	local sprite = obj:getSprite();
	if not sprite then return end;
	local props = sprite:getProperties();
	local hadWall = props:Is(IsoFlagType.cutN) or props:Is(IsoFlagType.cutW) or props:Is("WallW") or props:Is("WallN") or props:Is("WallNW");

	local args = {}
	args.x = sq:getX();
	args.y = sq:getY();
	args.z = sq:getZ();
	args.hadWall = hadWall;

	if isClient() then
		-- print("Sending client command bcGravity.OnTileRemoved");
		sendClientCommand('bcGravity', 'OnTileRemoved', args);
	elseif (not isClient()) and (not isServer()) then
		-- TODO XXX
		bcGravity.squares = {};

		if hadWall and sq:getZ() < 7 then
			for x=sq:getX()-bcGravity.radius,sq:getX()+bcGravity.radius do
				for y=sq:getY()-bcGravity.radius,sq:getY()+bcGravity.radius do
					bcGravity.checkSquare(x, y, sq:getZ()+1);
				end
			end
		end

		for x=sq:getX()-bcGravity.radius,sq:getX()+bcGravity.radius do
			for y=sq:getY()-bcGravity.radius,sq:getY()+bcGravity.radius do
				bcGravity.checkSquare(x, y, sq:getZ());
			end
		end

		bcGravity.obeyGravity();
	end
	bcGravity.preventLoop = false;
end
-- }}}

bcGravity.initClient = function()
	-- print("bcGravity: creating OnTileRemoved");
	triggerEvent("OnTileRemoved", {});
	Events.OnTileRemoved.Add(bcGravity.OnTileRemoved);
	Events.OnServerCommand.Add(bcGravity.ReceiveFromServer);
end

Events.OnGameStart.Add(bcGravity.initClient);

bcGravity.initServer = function()
	-- print("bcGravity.initServer START");
	Events.OnClientCommand.Add(bcGravity.ReceiveFromClient);
	-- print("bcGravity.initServer END");
end

Events.OnServerStarted.Add(bcGravity.initServer)
