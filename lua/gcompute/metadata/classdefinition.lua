local self = {}
GCompute.ClassDefinition = GCompute.MakeConstructor (self, GCompute.NamespaceDefinition)

--- @param The name of this type
-- @param typeParameterList A TypeParameterList describing the parameters the type takes or nil if the type is non-parametric
function self:ctor (name, typeParameterList)
	-- Children
	self.Namespace = GCompute.ClassNamespace ()
	self.Namespace:SetDefinition (self)
	
	-- Class
	self.ClassType = GCompute.ClassType (self)
	self.ClassType:SetNullable (true)
	
	-- Type Parameters
	self.TypeParameterList = typeParameterList or GCompute.EmptyTypeParameterList
	if #self.TypeParameterList > 0 then
		self.TypeParameterList = GCompute.TypeParameterList (self.TypeParameterList)
	end
	self.TypeArgumentList = GCompute.EmptyTypeArgumentList
	
	self.TypeParametricClassDefinition = self
	self.TypeCurriedDefinitions        = GCompute.WeakValueTable ()
	self.TypeCurryerFunction           = GCompute.NullCallback
	
	for i = 1, self:GetTypeParameterList ():GetParameterCount () do
		self:AddTypeParameter (self:GetTypeParameterList ():GetParameterName (i))
			:SetTypeParameterPosition (i)
	end
	
	-- Default value
	self.DefaultValueCreator = nil
end

-- System
function self:SetGlobalNamespace (globalNamespace)
	if self.GlobalNamespace == globalNamespace then return end
	
	self.GlobalNamespace = globalNamespace
	self.ClassType:SetGlobalNamespace (globalNamespace)
	self:GetNamespace ():SetTypeSystem (globalNamespace)
end

function self:SetTypeSystem (typeSystem)
	if self.TypeSystem == typeSystem then return end
	
	self.TypeSystem = typeSystem
	self.ClassType:SetTypeSystem (typeSystem)
	self:GetNamespace ():SetTypeSystem (typeSystem)
end

-- Hierarchy
--- Gets the short name of this type
-- @return The short name of this type
function self:GetShortName ()
	if self:GetTypeParameterList ():IsEmpty () then
		return self:GetName () or "[Unnamed]"
	elseif self:GetTypeArgumentList ():IsEmpty () then
		return (self:GetName () or "[Unnamed]") .. " " .. self:GetTypeParameterList ():ToString ()
	else
		return (self:GetName () or "[Unnamed]") .. " " .. self:GetTypeArgumentList ():ToString ()
	end
end

-- Class
local namespaceForwardedFunctions =
{
	"AddConstructor",
	"AddExplicitCast",
	"AddImplicitCast",
	"GetConstructor",
	"GetConstructorCount",
	"GetConstructorEnumerator",
	"GetExplicitCast",
	"GetExplicitCastCount",
	"GetExplicitCastEnumerator",
	"GetImplicitCast",
	"GetImplicitCastCount",
	"GetImplicitCastEnumerator"
}

for _, functionName in ipairs (namespaceForwardedFunctions) do
	self [functionName] = function (self, ...)
		local namespace = self:GetNamespace () 
		return namespace [functionName] (namespace, ...)
	end
end

local typeForwardedFunctions =
{
	"AddBaseType",
	"GetBaseType",
	"GetBaseTypeCount",
	"GetBaseTypeEnumerator",
	"IsBaseType",
	"IsBaseTypeOf",
	"SetNativelyAllocated",
	"SetNullable",
	"SetPrimitive"
}

for _, functionName in ipairs (typeForwardedFunctions) do
	self [functionName] = function (self, ...)
		local classType = self:GetClassType ()
		return classType [functionName] (classType, ...)
	end
end

function self:CanConstructFrom (sourceType)
	local argumentTypeArray = { sourceType }
	for _, constructorDefinition in ipairs (self.Constructors) do
		if constructorDefinition:GetType ():CanAcceptArgumentTypes (argumentTypeArray) then
			return true
		end
	end
	return false
end

function self:CanExplicitCastTo (destinationType)
	for explicitCast in self:GetNamespace ():GetExplicitCastEnumerator () do
		if explicitCast:GetReturnType ():Equals (destinationType) then
			return true
		end
	end
	return false
end

function self:CanImplicitCastTo (destinationType)
	for implicitCast in self:GetNamespace ():GetImplicitCastEnumerator () do
		if implicitCast:GetReturnType ():Equals (destinationType) then
			return true
		end
	end
	return false
end

function self:CreateDefaultValue ()
	if self:GetClassType ():IsNullable () then return nil end
	if self:GetClassType ():IsNativelyAllocated () then
		if self.DefaultValueCreator then
			return self.DefaultValueCreator (self)
		else
			-- Find a nullary constructor
			for constructor in self:GetNamespace ():GetConstructorEnumerator () do
				if constructor:GetParameterList ():MatchesArgumentCount (0) then
					return constructor:GetNativeFunction () ()
				end
			end
			GCompute.Error ("ClassDefinition:CreateDefaultValue : No nullary constructor or default value creator found for non-nullable natively allocated type (" .. self:GetFullName () .. ")")
			return
		end
	end
	GCompute.Error ("ClassDefinition:CreateDefaultValue : Not implemented for non-nullable non-natively allocated types (" .. self:GetFullName () .. ").")
end

function self:GetClassType ()
	return self.ClassType
end

function self:GetDefaultValueCreator ()
	return self.DefaultValueCreator
end

--- Gets whether this object is a MergedClassDefinition
-- @return A boolean indicating whether this object is a MergedClassDefinition
function self:IsMergedClassDefinition ()
	return false
end

function self:SetDefaultValueCreator (defaultValueCreator)
	self.DefaultValueCreator = defaultValueCreator
end

-- Type Parameters
function self:IsConcreteType ()
	if self:GetDeclaringType () and not self:GetDeclaringType ():IsConcreteType () then return false end
	if self.TypeParameterList:IsEmpty () then return true end
	return self.TypeParameterList:GetParameterCount () <= self.TypeArgumentList:GetArgumentCount ()
end

--- Gets the type argument list of this class
-- @return The type argument list of this class
function self:GetTypeArgumentList ()
	return self.TypeArgumentList
end

function self:GetTypeCurryerFunction ()
	return self.TypeCurryerFunction
end

--- Gets the type parameter list of this class
-- @return The type parameter list of this class
function self:GetTypeParameterList ()
	return self.TypeParameterList
end

function self:GetTypeParametricClassDefinition ()
	return self.TypeParametricClassDefinition
end

--- Gets the number of unbound local type parameters of this ClassDefinition
-- @return The number of unbound local type parameters of this ClassDefinition
function self:GetUnboundLocalTypeParameterCount ()
	if self.TypeParameterList:IsEmpty () then return 0 end
	if self.TypeParameterList:GetParameterCount () <= self.TypeArgumentList:GetArgumentCount () then return 0 end
	return self.TypeParameterList:GetParameterCount () - self.TypeArgumentList:GetArgumentCount ()
end

--- Returns true if this ClassDefinition has unbound local type parameters
-- @return A boolean indicating whether this ClassDefinition has unbound local type parameters
function self:HasUnboundLocalTypeParameters ()
	if self.TypeParameterList:IsEmpty () then return false end
	return self.TypeParameterList:GetParameterCount () > self.TypeArgumentList:GetArgumentCount ()
end

function self:SetTypeArgumentList (typeArgumentList)
	self.TypeArgumentList = typeArgumentList
end

function self:SetTypeCurryerFunction (typeCurryerFunction)
	self.TypeCurryerFunction = typeCurryerFunction
end

function self:SetTypeParametricClassDefinition (typeParametricClassDefinition)
	self.TypeParametricClassDefinition = typeParametricClassDefinition
end

-- Definition
function self:CreateRuntimeObject ()
	return
	{
		[".Type"] = self
	}
end

function self:GetCorrespondingDefinition (globalNamespace)
	if not self:GetDeclaringObject () then
		return globalNamespace
	end
	
	local leftNamespace = self:GetDeclaringObject ():GetCorrespondingDefinition (globalNamespace)
	local memberDefinition = leftNamespace:GetMember (self:GetName ())
	if memberDefinition:IsOverloadedClass () then
		local typeParameterCount = self:GetTypeParameterList ():GetParameterCount ()
		for class in memberDefinition:GetEnumerator () do
			if class:GetTypeParameterList ():GetParameterCount () == typeParameterCount then
				return class
			end
		end
		GCompute.Error ("ClassDefinition:GetCorrespondingDefinition : Corresponding ClassDefinition not found.")
		return nil
	elseif memberDefinition:IsClass () then
		return memberDefinition
	else
		GCompute.Error ("ClassDefinition:GetCorrespondingDefinition : Corresponding ObjectDefinition is not a ClassDefinition.")
		return nil
	end
end

function self:GetDisplayText ()
	local displayText = self:GetShortName ()
	
	if self:GetBaseTypeCount () > 0 then
		displayText = displayText .. " : "
		for i = 1, self:GetBaseTypeCount () do
			if i > 1 then
				displayText = displayText .. ", "
			end
			displayText = displayText .. self:GetBaseType (i):GetRelativeName (self)
		end
	end
	return displayText
end

--- Returns the Type of this object
-- @return A Type representing the type of this object
function self:GetType ()
	return self:GetTypeSystem ():GetType ()
end

function self:IsNamespace ()
	return false
end

--- Gets whether this object is a ClassDefinition
-- @return A boolean indicating whether this object is a ClassDefinition
function self:IsClass ()
	return true
end

function self:IsType ()
	return true
end

--- Resolves the types in this namespace
function self:ResolveTypes (globalNamespace, errorReporter)
	errorReporter = errorReporter or GCompute.DefaultErrorReporter
	
	-- Resolve base types
	self:GetClassType ():ResolveTypes (globalNamespace, errorReporter)
	
	-- Resolve member types
	self:GetNamespace ():ResolveTypes (globalNamespace, errorReporter)
	
	for _, typeCurriedDefinition in pairs (self.TypeCurriedDefinitions) do
		typeCurriedDefinition:ResolveTypes (globalNamespace, errorReporter)
	end
end

--- Returns a string representation of this type
-- @return A string representing this type
function self:ToString ()
	local classDefinition = (self:IsMergedClassDefinition () and "[Merged Type]" or "[Type]") .. " " .. (self:GetName () or "[Unnamed]")
	if not self:GetTypeParameterList ():IsEmpty () then
		classDefinition = classDefinition .. self:GetTypeParameterList ():ToString ()
	end
	
	if self:GetBaseTypeCount () > 0 then
		classDefinition = classDefinition .. " : "
		for i = 1, self:GetBaseTypeCount () do
			if i > 1 then
				classDefinition = classDefinition .. ", "
			end
			classDefinition = classDefinition .. self:GetBaseType (i):GetRelativeName (self)
		end
	end
	
	local namespace = self:GetNamespace ()
	if namespace:IsEmpty () then
		classDefinition = classDefinition.. " { }"
	else
		classDefinition = classDefinition .. "\n{\n"
		local newlineRequired = false
		
		if namespace:GetConstructorCount () > 0 then
			classDefinition = classDefinition .. "    // Constructors\n"
			newlineRequired = true
		end
		for constructor in namespace:GetConstructorEnumerator () do
			classDefinition = classDefinition .. "    " .. constructor:ToString ():gsub ("\n", "\n    ") .. "\n"
		end
		
		local firstMember = true
		for _, member in namespace:GetEnumerator () do
			if firstMember then
				if newlineRequired then classDefinition = classDefinition .. "    \n" end
				newlineRequired = true
				firstMember = false
			end
			classDefinition = classDefinition .. "    " .. member:ToString ():gsub ("\n", "\n    ") .. "\n"
		end
		
		if namespace:GetImplicitCastCount () > 0 or namespace:GetExplicitCastCount () > 0 then
			if newlineRequired then classDefinition = classDefinition .. "    \n" end
			classDefinition = classDefinition .. "    // Casts\n"
			newlineRequired = true
		end
		for implicitCast in namespace:GetImplicitCastEnumerator () do
			classDefinition = classDefinition .. "    " .. implicitCast:ToString ():gsub ("\n", "\n    ") .. "\n"
		end
		for explicitCast in namespace:GetExplicitCastEnumerator () do
			classDefinition = classDefinition .. "    " .. explicitCast:ToString ():gsub ("\n", "\n    ") .. "\n"
		end
		
		classDefinition = classDefinition .. "}"
	end
	
	return classDefinition
end

function self:ToType ()
	return self:GetClassType ()
end