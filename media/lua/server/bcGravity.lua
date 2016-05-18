require "TimedActions/ISDestroyStuffAction.lua"

bcGravity = {};
bcGravity.squares = {};
bcGravity.ISDestroyStuffActionPerform = ISDestroyStuffAction.perform;

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
	sq:transmitRemoveItemFromSquare(item);
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
		end
	end
end
--}}}
bcGravity.dropItemsDown = function(sq, item)--{{{
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
		end
	end
end
--}}}
bcGravity.itsTheLaw = function(_x, _y, _z)--{{{
	if _z < 1 then return; end

	local x;
	local y;
	local sq;
	local destroyedSomething = false;
	local additionalSquares = {};

	sq = getCell():getGridSquare(_x, _y, _z);
	if not sq then return end;

	for x=_x-1,_x+1 do
		for y=_y-1,_y+1 do
			if bcGravity.sqHasWall(getCell():getGridSquare(x, y, _z-1)) then
				return;
			end
		end
	end

	for i = sq:getObjects():size(),1,-1 do
		local obj = sq:getObjects():get(i-1);

		if instanceof(obj, "IsoWorldInventoryObject") then
			bcGravity.dropItemsDown(sq, obj);
		else -- not an IsoWorldInventoryObject
			bcGravity.destroyObject(obj);
			sq:playSound("breakdoor", true);
		end
		if not bcGravity.sqHasWall(sq) then
			table.insert(additionalSquares, getCell():getGridSquare(_x, _y, _z));
		end
		destroyedSomething = true;
	end

	for i = sq:getStaticMovingObjects():size(),1,-1 do
		local obj = sq:getStaticMovingObjects():get(i-1);
		bcGravity.dropStaticMovingItemsDown(sq, obj);
	end

	for _,sq in pairs(additionalSquares) do
		for x=sq:getX()-1,sq:getX()+1 do
			for y=sq:getY()-1,sq:getY()+1 do
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
function ISDestroyStuffAction.perform(self)--{{{
	local x;
	local y;
	local sq = self.item:getSquare();
	local hadWall = bcGravity.sqHasWall(sq);
	-- call original function
	bcGravity.ISDestroyStuffActionPerform(self)
	if not hadWall then return end;

	bcGravity.squares = {};

	if sq:getZ() < 7 then
		if not bcGravity.sqHasWall(sq) then
			for x=sq:getX()-3,sq:getX()+3 do
				for y=sq:getY()-3,sq:getY()+3 do
					bcGravity.checkSquare(x, y, sq:getZ()+1);
				end
			end
		end
	end

	for x=sq:getX()-3,sq:getX()+3 do
		for y=sq:getY()-3,sq:getY()+3 do
			bcGravity.checkSquare(x, y, sq:getZ());
		end
	end

	bcGravity.obeyGravity();
end
--}}}
