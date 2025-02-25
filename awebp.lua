local _module_0 = { }
local struct = require('lib.struct')
local _anon_func_0 = function(_, _close_0, error, _arg_0, ...)
	do
		local _ok_0 = _arg_0
		_close_0(_)
		if _ok_0 then
			return ...
		else
			return error(...)
		end
	end
end
local readChunks
readChunks = function(filecontent)
	local read
	read = function(n)
		local result
		result, filecontent = filecontent:sub(1, n), filecontent:sub(n + 1)
		return result
	end
	local read_chunk
	read_chunk = function()
		local raw = read(8)
		local id, size = struct.unpack('<c4I', raw)
		pp(id, size)
		local _ = setmetatable({ }, {
			__close = function()
				if size % 2 == 1 then
					return read(1)
				end
			end
		})
		local _close_0 = assert(getmetatable(_).__close)
		return _anon_func_0(_, _close_0, error, pcall(function()
			if 'VP8X' == id then
				local flags, w1, w2, h1, h2 = struct.unpack('<IHBHB', read(10))
				return {
					id = id,
					flags = flags,
					width = 1 + w1 + w2 * 65536,
					height = 1 + h1 + h2 * 65536
				}
			elseif 'ANIM' == id then
				local r, g, b, a, loops = struct.unpack('<BBBBH', read(6))
				return {
					id = id,
					bgcolor = {
						r / 255,
						g / 255,
						b / 255,
						a / 255
					},
					loops = loops
				}
			elseif 'ANMF' == id then
				local l1, l2, t1, t2, w1, w2, h1, h2, d1, d2, flags = struct.unpack('<HBHBHBHBHBB', read(16))
				return {
					id = id,
					left = (l1 + l2 * 65536) * 2,
					top = (t1 + t2 * 65536) * 2,
					width = 1 + w1 + w2 * 65536,
					height = 1 + h1 + h2 * 65536,
					duration = (d1 + d2 * 65536) / 1000,
					blend = math.floor(flags / 2) % 2,
					dispose = flags % 2,
					chunks = readChunks(read(size - 16))
				}
			else
				return {
					id = id,
					data = read(size)
				}
			end
		end))
	end
	local _accum_0 = { }
	local _len_0 = 1
	while #filecontent >= 8 do
		_accum_0[_len_0] = read_chunk()
		_len_0 = _len_0 + 1
	end
	return _accum_0
end
local readAWebp
readAWebp = function(filecontent)
	local sig1, size, sig2 = struct.unpack('<c4Ic4', filecontent)
	assert(sig1 == 'RIFF')
	assert(sig2 == 'WEBP')
	assert(size + 8 == #filecontent)
	return readChunks(filecontent:sub(13, -1))
end
local read1frame
read1frame = function(frame)
	local chunk = frame.chunks[1]
	assert(chunk.id == 'VP8L' or chunk.id == 'VP8 ')
	local data = 'RIFF' .. struct.pack('<I', 4 + 18 + 8 + #chunk.data) .. 'WEBP' .. 'VP8X' .. struct.pack('<IIHBHB', 10, frame.vp8x.flags - 2, math.floor((frame.width - 1) % 65536), math.floor((frame.width - 1) / 65536), math.floor((frame.height - 1) % 65536), math.floor((frame.height - 1) / 65536)) .. chunk.id .. struct.pack('<I', #chunk.data) .. chunk.data
	love.filesystem.write('1.webp', data)
	return gr.newImage(love.data.newByteData(data))
end
local AWebp
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
					gr.clear(self.bgcolor)
					return gr.setScissor()
				end
			elseif 2 == _exp_0 then
				self._dispose = nil
			end
		end
		do
			local _exp_0 = frame.blend
			if 1 == _exp_0 then
				gr.setScissor(frame.left, frame.top, frame.width, frame.height)
				gr.clear(self.bgcolor)
				gr.setScissor()
			end
		end
		gr.draw(gr.setColor(1, 1, 1) or frame.image, frame.left, frame.top)
		return gr.setCanvas()
	end,
	update = function(self, dt)
		self.clock = self.clock + dt
		while self.clock > self.frames[self.index].duration do
			self.clock = self.clock - self.frames[self.index].duration
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
		local chunks = readAWebp(filecontent)
		local vp8x
		self.loops, self.bgcolor, self.frames, vp8x = 1, {
			0,
			0,
			0,
			1
		}, { }, nil
		for _index_0 = 1, #chunks do
			local chunk = chunks[_index_0]
			local _exp_0 = chunk.id
			if 'VP8X' == _exp_0 then
				vp8x = chunk
			elseif 'ANIM' == _exp_0 then
				self.bgcolor, self.loops = chunk.bgcolor, chunk.loops > 0 and chunk.loops or math.huge
			elseif 'ANMF' == _exp_0 then
				local _obj_0 = self.frames
				local _tab_0 = { }
				local _idx_0 = 1
				for _key_0, _value_0 in pairs(chunk) do
					if _idx_0 == _key_0 then
						_tab_0[#_tab_0 + 1] = _value_0
						_idx_0 = _idx_0 + 1
					else
						_tab_0[_key_0] = _value_0
					end
				end
				_tab_0.vp8x = vp8x
				_obj_0[#_obj_0 + 1] = _tab_0
			end
		end
		self.canvas = gr.newCanvas(vp8x.width, vp8x.height)
		self.clock, self.index = 0, 1
		return self:update1frame(self.frames[1])
	end,
	__base = _base_0,
	__name = "AWebp"
}, {
	__index = _base_0,
	__call = function(cls, ...)
		local _self_0 = setmetatable({ }, _base_0)
		cls.__init(_self_0, ...)
		return _self_0
	end
})
_base_0.__class = _class_0
AWebp = _class_0
_module_0["AWebp"] = AWebp
return _module_0
