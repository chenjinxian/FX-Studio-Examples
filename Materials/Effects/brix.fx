/************* Resources *************/

cbuffer CBufferPerObject
{
	float4x4 WorldITXf : WorldInverseTranspose	< string UIWidget = "None"; >;
	float4x4 WvpXf     : WorldViewProjection	< string UIWidget = "None"; >;
	float4x4 WorldXf   : World					< string UIWidget = "None"; >;
	float4x4 ViewIXf   : ViewInverse			< string UIWidget = "None"; >;

	float3 Lamp0Dir : DIRECTION <
		string Object = "DirectionalLight0";
		string UIName = "Lamp 0 Direction";
		string Space = "World";
	> = { 0.7f,-0.7f,-0.7f };
}

cbuffer CBufferPerFrame
{
	float3 AmbiColor : Ambient <
		string UIName = "Ambient Light";
		string UIWidget = "Color";
	> = { 0.17f, 0.17f, 0.17f };

	float4 SurfColor1 <
		string UIName = "Brick 1";
		string UIWidget = "Color";
	> = { 0.9, 0.5, 0.0, 1.0f };

	float4 SurfColor2 <
		string UIName = "Brick 2";
		string UIWidget = "Color";
	> = { 0.8, 0.48, 0.15, 1.0f };

	float4 GroutColor <
		string UIName = "Grouting";
		string UIWidget = "Color";
	> = { 0.8f, 0.75f, 0.75f, 1.0f };

	float BrickWidth : UNITSSCALE <
		string UNITS = "inches";
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 0.35;
		float UIStep = 0.001;
		string UIName = "Brick Width";
	> = 0.3;

	float BrickHeight : UNITSSCALE <
		string UNITS = "inches";
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 0.35;
		float UIStep = 0.001;
		string UIName = "Brick Height";
	> = 0.12;

	float GBalance <
		string UIWidget = "slider";
		float UIMin = 0.01;
		float UIMax = 0.35;
		float UIStep = 0.01;
		string UIName = "Grout::Brick Ratio";
	> = 0.1;
}

Texture2D StripTexture <
	string ResourceName = "Strip.dds";
	string UIName = "Special Mipped Stripe";
	string ResourceType = "2D";
>;

SamplerState StripeSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
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
	float3 WorldView		: TEXCOORD1;
	float4 DColor			: COLOR;
};

/************* Vertex Shader *************/

VS_OUTPUT vertex_shader(VS_INPUT IN)
{
	VS_OUTPUT OUT = (VS_OUTPUT)0;

	float4 Po = float4(IN.Position.xyz, 1.0);
	OUT.HPosition = mul(Po, WvpXf);

	OUT.WorldNormal = normalize(mul(float4(IN.Normal, 0), WorldITXf).xyz);

	float3 Pw = mul(Po, WorldXf).xyz;
#ifdef FLIP_TEXTURE_Y
	OUT.UV = float2(IN.UV.y / BrickWidth, IN.UV.x / BrickHeight);
#else
	OUT.UV = float2(IN.UV.x / BrickWidth, IN.UV.y / BrickHeight);
#endif
	OUT.WorldView = normalize(ViewIXf[3].xyz - Pw);

	float lamb = saturate(dot(OUT.WorldNormal, -Lamp0Dir));
	OUT.DColor = float4((lamb.xxx + AmbiColor).rgb, 1.0);

	return OUT;
}

/************* Pixel Shader *************/

float4 pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float grout = GBalance;

	float v = StripTexture.Sample(StripeSampler, float2(IN.UV.x, 0.5)).x;
	float4 dColor1 = lerp(SurfColor1, SurfColor2, v);
	v = StripTexture.Sample(StripeSampler, float2(IN.UV.x * 2, grout)).x;
	dColor1 = lerp(GroutColor, dColor1, v);

	v = StripTexture.Sample(StripeSampler, float2(IN.UV.x + 0.25, 0.5)).x;
	float4 dColor2 = lerp(SurfColor1, SurfColor2, v);
	v = StripTexture.Sample(StripeSampler, float2((IN.UV.x + 0.25) * 2, grout)).x;
	dColor2 = lerp(GroutColor, dColor2, v);

	v = StripTexture.Sample(StripeSampler, float2(IN.UV.y, 0.5)).x;
	float4 brix = lerp(dColor1, dColor2, v);
	v = StripTexture.Sample(StripeSampler, float2(IN.UV.y * 2, grout)).x;
	brix = lerp(GroutColor, brix, v);

	float4 result = IN.DColor * brix;
	return result;
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
