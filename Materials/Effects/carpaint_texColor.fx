/************* Resources *************/

cbuffer CBufferPerObject
{
	float4x4 WorldITXf : WorldInverseTranspose	< string UIWidget = "None"; >;
	float4x4 WvpXf     : WorldViewProjection	< string UIWidget = "None"; >;
	float4x4 WorldXf   : World					< string UIWidget = "None"; >;
	float4x4 ViewIXf   : ViewInverse			< string UIWidget = "None"; >;

	float3 Lamp0Pos : POSITION <
		string Object = "PointLight0";
		string UIName = "Lamp 0 Position";
		string Space = "World";
	> = { -0.5f, 2.0f, 1.25f };

	float3 Lamp0Color : SPECULAR <
		string Object = "Pointlight0";
		string UIName = "Lamp 0 Color";
		string UIWidget = "Color";
	> = { 1.0f, 1.0f, 1.0f };
}

cbuffer CBufferPerFrame
{
	float3 AmbiColor : Ambient <
		string UIName = "Ambient Light";
		string UIWidget = "Color";
	> = { 0.07f, 0.07f, 0.07f };

	float SpecExpon <
		string UIWidget = "slider";
		float UIMin = 1.0;
		float UIMax = 128.0;
		float UIStep = 1.0;
		string UIName = "Specular Exponent";
	> = 55.0;
}

Texture2D CarpaintMap <
	string ResourceName = "CarpaintMap.dds";
	string UIName = "Car Paint BRDF Map";
	string ResourceType = "2D";
>;

SamplerState CarpaintSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

/************* Data Structures *************/

struct VS_INPUT
{
	float3 Position	: POSITION;
	float2 UV		: TEXCOORD0;
	float3 Normal	: NORMAL;
};

struct VS_OUTPUT
{
	float4 HPosition		: SV_Position;
	float3 WorldNormal		: NORMAL;
	float2 UV				: TEXCOORD0;
	float3 LightVec			: TEXCOORD1;
	float3 WorldView		: TEXCOORD2;
	float2 BrdfTerms		: TEXCOORD3; // dot prods against half-angle
};

/************* Vertex Shader *************/

VS_OUTPUT vertex_shader(VS_INPUT IN)
{
	VS_OUTPUT OUT = (VS_OUTPUT)0;

	float4 Po = float4(IN.Position.xyz, 1.0);
	OUT.HPosition = mul(Po, WvpXf);

	OUT.WorldNormal = normalize(mul(float4(IN.Normal, 0), WorldITXf).xyz);

	float3 Pw = mul(Po, WorldXf).xyz;
	OUT.LightVec = normalize(Lamp0Pos - Pw);
#ifdef FLIP_TEXTURE_Y
	OUT.UV = float2(IN.UV.x, (1.0 - IN.UV.y));
#else
	OUT.UV = IN.UV;
#endif
	OUT.WorldView = normalize(ViewIXf[3].xyz - Pw);

	float3 flipN = faceforward(OUT.WorldNormal, -OUT.WorldView, OUT.WorldNormal);
	float3 halfN = normalize(OUT.WorldView + OUT.LightVec);
	float aldn = abs(dot(OUT.LightVec, flipN));
	float ahdn = 1.0 - abs(dot(halfN, flipN));
	OUT.BrdfTerms = float2(aldn, ahdn);

	OUT.WorldNormal = flipN;

	return OUT;
}

/************* Pixel Shader *************/
float4 brdf_texture(VS_OUTPUT IN)
{
	return CarpaintMap.Sample(CarpaintSampler, IN.BrdfTerms);
}

float4 pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float3 surfCol = brdf_texture(IN).rgb;

	float3 flipN = faceforward(IN.WorldNormal, -IN.WorldView, IN.WorldNormal);
	float3 halfN = normalize(IN.WorldView + IN.LightVec);
	float ldn = dot(flipN, IN.LightVec);
	float hdn = dot(halfN, IN.LightVec);

	float4 litV = lit(ldn, hdn, SpecExpon);
	float3 diff = surfCol * (litV.yyy + AmbiColor);
	float3 spec = litV.y * litV.z * Lamp0Color;
	return float4((diff + spec).rgb, 1.0);
}

RasterizerState DisableCulling
{
	CullMode = NONE;
};

/************* Techniques *************/

technique11 main11
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, pixel_shader()));

		SetRasterizerState(DisableCulling);
	}
}
