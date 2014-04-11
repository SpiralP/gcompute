local self = {}
GCompute.Execution.RemoteExecutionServiceClient = GCompute.MakeConstructor (self, GLib.Networking.SingleEndpointNetworkable, GCompute.Execution.IExecutionService)
GCompute.Services.RemoteServiceRegistry:RegisterServiceClient ("ExecutionService", GCompute.Execution.RemoteExecutionServiceClient)

function self:ctor ()
	GCompute.Debug ("RemoteExecutionServiceClient:ctor ()")
end

function self:dtor ()
	if not self.NetworkableHost then return end
	
	GCompute.Debug ("RemoteExecutionServiceClient:dtor ()")
	
	local outBuffer = GLib.Net.OutBuffer ()
	outBuffer:UInt32 (0)
	self:DispatchPacket (self:GetRemoteId (), outBuffer)
	
	self.NetworkableHost:UnregisterNetworkable (self)
end

-- Networkable
function self:HandlePacket (sourceId, inBuffer)
	
end

-- IExecutionService
function self:CanCreateExecutionContext (authId, hostId, languageName)
	return true
end

function self:CreateExecutionContext (authId, hostId, languageName, contextOptions, callback)
	if callback then GLib.CallSelfAsSync () return end
	
	if self:IsDisposed () then return nil, GCompute.ReturnCode.NoCarrier end
	
	-- Check
	local allowed, denialReason = self:CanCreateExecutionContext (authId, hostId, languageName)
	if not allowed then return nil, denialReason end
	
	-- Create request session
	local connection = self.NetworkableHost:CreateConnection (self:GetRemoteId (), GLib.Net.ConnectionEndpoint.Local)
	
	-- Create request
	local outBuffer = GLib.Net.OutBuffer ()
	outBuffer:UInt32 (connection:GetId ())
	outBuffer:StringN8 ("CreateExecutionContext")
	outBuffer:StringN16 (authId)
	if istable (hostId) then
		outBuffer:UInt16 (#hostId)
		for _, hostId in ipairs (hostId) do
			outBuffer:StringN16 (hostId)
		end
	else
		outBuffer:UInt16 (1)
		outBuffer:StringN16 (hostId)
	end
	outBuffer:StringN16 (languageName)
	outBuffer:UInt32 (contextOptions)
	
	-- Dispatch request
	self:DispatchPacket (self:GetRemoteId (), outBuffer)
	
	-- Wait for response
	local inBuffer = connection:Read ()
	connection:Close ()
	
	if not inBuffer then return nil, GCompute.ReturnCode.Timeout end
	
	local returnCode = inBuffer:UInt8 ()
	
	if returnCode ~= GCompute.ReturnCode.Success then
		return false, returnCode
	end
	
	-- GOGOGO
	local networkableId = inBuffer:UInt32 ()
	local executionContextClient = GCompute.Execution.RemoteExecutionContextClient (self, inBuffer)
	executionContextClient:SetRemoteId (self:GetRemoteId ())
	
	self.NetworkableHost:RegisterNetworkable (executionContextClient, networkableId)
	
	return executionContextClient
end

function self:GetHostEnumerator ()
	return GLib.NullEnumerator ()
end

function self:GetLanguageEnumerator ()
	return GLib.NullEnumerator ()
end

function self:IsAvailable ()
	return true
end