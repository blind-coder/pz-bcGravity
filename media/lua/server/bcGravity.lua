-- require "TimedActions/ISDestroyStuffAction.lua"
require "BuildingObjects/ISWoodenFloor.lua"
require "bcUtils"

bcGravity = {};
bcGravity.radius = 2;
bcGravity.preventLoop = false;
bcGravity.squares = {};
bcGravity.ISDestroyStuffActionPerform = ISDestroyStuffAction.perform;

bcGravity.ISWFisValid = ISWoodenFloor.isValid; -- {{{
ISWoodenFloor.isValid = function(self, square)
	local _x = square:getX();
	local _y = square:getY();
	local _z = square:getZ();
	if not bcGravity.ISWFisValid(self, square) then return false end;
	for x=_x-3,_x+3 do
		for y=_y-3,_y+3 do
			if bcGravity.sqHasWall(getCell():getGridSquare(x, y, _z-1)) then
				return true;
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
		for j=1,container:getItems():size() do
			local item = obj:getSquare():AddWorldInventoryItem(container:getItems():get(j-1), 0.0, 0.0, 0.0)
			bcGravity.dropItemsDown(obj:getSquare(), item);
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
	if isClient() then
		local sq = obj:getSquare()
		local args = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), index = obj:getObjectIndex() }
		sendClientCommand(self.character, 'object', 'OnDestroyIsoThumpable', args)
	end

	-- Destroy all 3 stair objects (and sometimes the floor at the top)
	local stairObjects = buildUtil.getStairObjects(obj)
	if #stairObjects > 0 then
		for i=1,#stairObjects do
			if isClient() then
				sledgeDestroy(stairObjects[i]);
			else
				stairObjects[i]:getSquare():transmitRemoveItemFromSquare(stairObjects[i])
				stairObjects[i]:getSquare():RemoveTileObject(stairObjects[i])
			end
		end
	else
		if isClient() then
			sledgeDestroy(obj);
		else
			obj:getSquare():transmitRemoveItemFromSquare(obj)
			obj:getSquare():RemoveTileObject(obj)
		end
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
	sq:getStaticMovingObjects():remove(item);
	sq:getCell():render();
	for nz=sq:getZ(),0,-1 do
		local nsq = getCell():getGridSquare(sq:getX(), sq:getY(), nz);
		if nz == 0 or (nsq and nsq:getFloor()) then
			nsq:AddWorldInventoryItem(item:getItem(), 0.0 , 0.0, 0.0);
			if isClient() then
				item:transmitCompleteItemToServer();
			else
				item:transmitCompleteItemToClients();
			end
			return;
		end
	end
end
--}}}
bcGravity.dropItemsDown = function(sq, item)--{{{
	local id = -1;
	if instanceof(item, "InventoryItem") then
		id = item:getID();
		item = item:getWorldItem();
	end
	if not item then return end;

	sq:transmitRemoveItemFromSquare(item);
	sq:getWorldObjects():remove(item);
	sq:getSpecialObjects():remove(item);
	sq:getObjects():remove(item);
	for nz=sq:getZ(),0,-1 do
		local nsq = getCell():getGridSquare(sq:getX(), sq:getY(), nz);
		if nz == 0 or (nsq and nsq:getFloor()) then
			nsq:AddWorldInventoryItem(item:getItem(), 0.0 , 0.0, 0.0);
			if isClient() then
				item:transmitCompleteItemToServer();
			else
				item:transmitCompleteItemToClients();
			end
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
		else -- not an IsoWorldInventoryObject
			destroyedSomething = true;
			bcGravity.destroyObject(obj);
			sq:playSound("breakdoor", true);
		end
		if destroyedSomething and not bcGravity.sqHasWall(sq) then
			table.insert(additionalSquares, getCell():getGridSquare(_x, _y, _z));
		end
	end

	for i = sq:getStaticMovingObjects():size(),1,-1 do
		local obj = sq:getStaticMovingObjects():get(i-1);
		bcGravity.dropStaticMovingItemsDown(sq, obj);
	end

	if destroyedSomething then
		local moving = getCell():getGridSquare(_x, _y, _z-1);
		if not moving then return end
		moving = moving:getMovingObjects();
		for i = moving:size(),1,-1 do
			local ent = moving:get(i-1);
			if ent then
				local hits = 2+ZombRand(3);
				local hploss = 15 + ZombRand(15);
				for i=0,hits do
					ent:Hit(InventoryItemFactory.CreateItem("Base.Axe"), getCell():getFakeZombieForHit(), math.ceil(hploss / hits), false, 1.0F);
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

bcGravity.OnTileRemoved = function(obj) -- {{{
	if bcGravity.preventLoop then return end
	bcGravity.preventLoop = true;

	local sq = obj:getSquare();
	if not sq then
		print("error: obj:getSquare() is nil!");
		bcGravity.preventLoop = false;
		return;
	end

	local props = obj:getSprite():getProperties();
	local hadWall = props:Is(IsoFlagType.cutN) or props:Is(IsoFlagType.cutW) or props:Is("WallW") or props:Is("WallN") or props:Is("WallNW");

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
	
	bcGravity.preventLoop = false;
end
-- }}}

triggerEvent("OnTileRemoved", {});
Events.OnTileRemoved.Add(bcGravity.OnTileRemoved);
