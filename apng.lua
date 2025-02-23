local _module_0 = { }
local struct = require('lib.struct')
if not bit then
	_G.bit = require('lib.bitop')
end
local crc32 = require('lib.crc32').hash
local SIGNATURE = '\137PNG\13\10\26\10'
local readAPNG
readAPNG = function(filecontent)
	local read
	read = function(n)
		local result
		result, filecontent = filecontent:sub(1, n), filecontent:sub(n + 1)
		return result
	end
	local read_chunk
	read_chunk = function()
		local raw = read(8)
		local size, id = struct.unpack('>Ic4', raw)
		if 'IHDR' == id then
			local w, h, depth, colortype, compresstype, filter, interlace = struct.unpack('>IIBBBBB', read(size + 4))
			return {
				id = id,
				width = w,
				height = h,
				depth = depth,
				colortype = colortype,
				compresstype = compresstype,
				filter = filter,
				interlace = interlace
			}
		elseif 'acTL' == id then
			local frames, plays = struct.unpack('>II', read(size + 4))
			return {
				id = id,
				frames = frames,
				plays = plays
			}
		elseif 'fcTL' == id then
			local _, w, h, l, t, delay1, delay2, dispose, blend = struct.unpack('>IIIIIHHBB', read(size + 4))
			return {
				id = id,
				width = w,
				height = h,
				left = l,
				top = t,
				delay = delay1 / (delay2 > 0 and delay2 or 100),
				dispose = dispose,
				blend = blend
			}
		elseif 'fdAT' == id then
			return {
				id = id,
				_ = read(4),
				data = read(size - 4),
				__ = read(4)
			}
		else
			local data, crc = read(size), read(4)
			return {
				id = id,
				data = data,
				raw = raw .. data .. crc
			}
		end
	end
	assert(read(8) == SIGNATURE)
	local _accum_0 = { }
	local _len_0 = 1
	while #filecontent >= 12 do
		_accum_0[_len_0] = read_chunk()
		_len_0 = _len_0 + 1
	end
	return _accum_0
end
local tochunk
tochunk = function(id, data)
	return struct.pack('>Ic4', #data, id) .. data .. struct.pack('>I', crc32(id .. data))
end
local _anon_func_0 = function(frame, tochunk)
	local _accum_0 = { }
	local _len_0 = 1
	local _list_0 = frame.idats
	for _index_0 = 1, #_list_0 do
		local data = _list_0[_index_0]
		_accum_0[_len_0] = tochunk('IDAT', data)
		_len_0 = _len_0 + 1
	end
	return _accum_0
end
local read1frame
read1frame = function(frame)
	local data = SIGNATURE .. tochunk('IHDR', struct.pack('>IIBBBBB', frame.width, frame.height, frame.ihdr.depth, frame.ihdr.colortype, frame.ihdr.compresstype, frame.ihdr.filter, frame.ihdr.interlace)) .. (frame.pltechunk or '') .. (frame.trnschunk or '') .. table.concat(_anon_func_0(frame, tochunk)) .. frame.iendchunk
	return gr.newImage(love.filesystem.newFileData(data, '1.png'))
end
local APNG
local _class_0
local _base_0 = {
	update1frame = function(self, frame)
		frame.image = frame.image or read1frame(frame)
		gr.setCanvas(self.canvas)
		do
			local _obj_0 = self._dispose
			if _obj_0 ~= nil then
				_obj_0()
			end
		end
		do
			local _exp_0 = frame.dispose
			if 0 == _exp_0 then
				self._dispose = nil
			elseif 1 == _exp_0 then
				self._dispose = function()
					gr.setScissor(frame.left, frame.top, frame.width, frame.height)
					gr.clear(self.clearcolor)
					return gr.setScissor()
				end
			elseif 2 == _exp_0 then
				self._dispose = nil
			end
		end
		do
			local _exp_0 = frame.blend
			if 0 == _exp_0 then
				gr.setScissor(frame.left, frame.top, frame.width, frame.height)
				gr.clear(self.clearcolor)
				gr.setScissor()
			end
		end
		gr.draw(gr.setColor(1, 1, 1) or frame.image, frame.left, frame.top)
		return gr.setCanvas()
	end,
	update = function(self, dt)
		self.clock = self.clock + dt
		while self.clock > self.frames[self.index].delay do
			self.clock = self.clock - self.frames[self.index].delay
			if self.index < #self.frames then
				self.index = self.index + 1
			else
				self.plays = self.plays - 1
				if self.plays <= 0 then
					self.update = function(self) end
					return
				end
				self.index = 1
			end
			self:update1frame(self.frames[self.index])
		end
	end
}
if _base_0.__index == nil then
	_base_0.__index = _base_0
end
_class_0 = setmetatable({
	__init = function(self, filecontent)
		local chunks = readAPNG(filecontent)
		local ihdr, pltechunk, trnschunk, fctl, iendchunk
		self.plays, self.frames, ihdr, pltechunk, trnschunk, fctl, iendchunk = 1, { }, nil, nil, nil, nil, chunks[#chunks].raw
		for i = 1, #chunks do
			local chunk = chunks[i]
			local _exp_0 = chunk.id
			if 'IHDR' == _exp_0 then
				ihdr = chunk
			elseif 'PLTE' == _exp_0 then
				pltechunk = chunk.raw
			elseif 'tRNS' == _exp_0 then
				trnschunk = chunk.raw
			elseif 'acTL' == _exp_0 then
				self.plays = chunk.plays > 0 and chunk.plays or math.huge
			elseif 'fcTL' == _exp_0 then
				fctl = chunk
			elseif 'IDAT' == _exp_0 or 'fdAT' == _exp_0 then
				if fctl then
					local _obj_0 = self.frames
					local _tab_0 = { }
					local _idx_0 = 1
					for _key_0, _value_0 in pairs(fctl) do
						if _idx_0 == _key_0 then
							_tab_0[#_tab_0 + 1] = _value_0
							_idx_0 = _idx_0 + 1
						else
							_tab_0[_key_0] = _value_0
						end
					end
					_tab_0.idats = {
						chunk.data
					}
					_tab_0.ihdr = ihdr
					_tab_0.pltechunk = pltechunk
					_tab_0.trnschunk = trnschunk
					_tab_0.iendchunk = iendchunk
					_obj_0[#_obj_0 + 1] = _tab_0
				elseif #self.frames > 0 then
					local _obj_0 = self.frames[#self.frames].idats
					_obj_0[#_obj_0 + 1] = chunk.data
				end
				fctl = nil
			end
		end
		self.canvas = gr.newCanvas(ihdr.width, ihdr.height)
		self.clearcolor = {
			0,
			0,
			0,
			0
		}
		self.clock, self.index = 0, 1
		return self:update1frame(self.frames[1])
	end,
	__base = _base_0,
	__name = "APNG"
}, {
	__index = _base_0,
	__call = function(cls, ...)
		local _self_0 = setmetatable({ }, _base_0)
		cls.__init(_self_0, ...)
		return _self_0
	end
})
_base_0.__class = _class_0
APNG = _class_0
_module_0["APNG"] = APNG
return _module_0
