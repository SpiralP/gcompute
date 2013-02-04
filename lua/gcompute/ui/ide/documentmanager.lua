local self = {}
GCompute.IDE.DocumentManager = GCompute.MakeConstructor (self)

--[[
	Events:
		DocumentAdded (Document document)
			Fired when a document has been added.
		DocumentRemoved (Document document)
			Fired when a document has been removed.
]]

function self:ctor ()
	-- IDE
	self.IDE             = nil
	self.DocumentTypes   = nil
	
	-- Documents
	self.Documents       = {}
	self.DocumentsById   = {}
	self.DocumentsByPath = {}
	self.DocumentCount   = 0
	
	self.NextDocumentId  = 0
	
	GCompute.EventProvider (self)
end

-- IDE
function self:GetDocumentTypes ()
	return self.DocumentTypes
end

function self:GetIDE ()
	return self.IDE
end

function self:GetViewManager ()
	if not self.IDE then return nil end
	return self.IDE:GetViewManager ()
end

function self:SetDocumentTypes (documentTypes)
	self.DocumentTypes = documentTypes
end

function self:SetIDE (ide)
	self.IDE = ide
end

-- Documents
function self:AddDocument (document)
	if self.Documents [document] then return end
	
	self.Documents [document] = true
	if document:GetPath () then
		self.DocumentsByPath [document:GetPath ()] = document
	end
	if not document:GetId () then
		document:SetId (self:GenerateDocumentId (document))
	end
	self.DocumentsById [document:GetId ()] = document
	self.DocumentCount = self.DocumentCount + 1
	
	self:HookDocument (document)
	
	self:DispatchEvent ("DocumentAdded", document)
end

function self:GenerateDocumentId (document)
	while self.DocumentsById [tostring (self.NextDocumentId)] do
		self.NextDocumentId = self.NextDocumentId + 1
	end
	self.NextDocumentId = self.NextDocumentId + 1
	return tostring (self.NextDocumentId - 1)
end

function self:GetDocumentById (documentId)
	return self.DocumentsById [documentId]
end

function self:GetDocumentByPath (path)
	return self.DocumentsByPath [path]
end

function self:GetDocumentCount ()
	return self.DocumentCount
end

function self:GetEnumerator ()
	local next, tbl, key = pairs (self.Documents)
	return function ()
		key = next (tbl, key)
		return key
	end
end

function self:RemoveDocument (document)
	if not self.Documents [document] then return end
	
	self.Documents [document] = nil
	if document:GetPath () then
		self.DocumentsByPath [document:GetPath ()] = nil
	end
	self.DocumentsById [document:GetId ()] = nil
	self.DocumentCount = self.DocumentCount - 1
	
	self:UnhookDocument (document)
	
	self:DispatchEvent ("DocumentRemoved", document)
end

-- Persistance
function self:LoadSession (inBuffer, serializerRegistry)
	local documentId = inBuffer:String ()
	while documentId ~= "" do
		local documentType = inBuffer:String ()
		local subInBuffer = GLib.StringInBuffer (inBuffer:LongString ())
		local document = GCompute.IDE.DocumentTypes:Create (documentType)
		if document then
			document:SetId (documentId)
			document:LoadSession (subInBuffer, serializerRegistry)
			self:AddDocument (document)
		end
		
		inBuffer:Char () -- Discard newline
		documentId = inBuffer:String ()
	end
end

function self:SaveSession (outBuffer, serializerRegistry)
	local subOutBuffer = GLib.StringOutBuffer ()
	for document, _ in pairs (self.Documents) do
		outBuffer:String (document:GetId ())
		outBuffer:String (document:GetType ())
		subOutBuffer:Clear ()
		document:SaveSession (subOutBuffer, serializerRegistry)
		outBuffer:LongString (subOutBuffer:GetString ())
		outBuffer:Char ("\n")
	end
	outBuffer:String ("")
end

-- Internal, do not call
function self:HookDocument (document)
	if not document then return end
	
	document:AddEventListener ("PathChanged", tostring (self),
		function (_, oldPath, path)
			if oldPath then
				self.DocumentsByPath [oldPath] = nil
			end
			if path then
				self.DocumentsByPath [path] = document
			end
		end
	)
end

function self:UnhookDocument (document)
	if not document then return end
	
	document:RemoveEventListener ("PathChanged", tostring (self))
end