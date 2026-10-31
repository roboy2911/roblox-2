-- Our effect images (sparks, dust, glow, ring, trail). The server looks up
-- their IDs at startup (AssetService) and puts them here for clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = {}

local folder: Instance? = nil

-- The image ID for an effect image, or "" if it isn't ready or couldn't load.
function Images.Get(name: string): string
	if not folder then
		folder = ReplicatedStorage:FindFirstChild("ImageIds")
	end
	return if folder then folder:GetAttribute(name) or "" else ""
end

return Images
