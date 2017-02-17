/************* Resources *************/

cbuffer CBufferPerObject
{
	float4x4 WorldITXf : WorldInverseTranspose	< string UIWidget = "None"; >;
	float4x4 WvpXf     : WorldViewProjection	< string UIWidget = "None"; >;
	float4x4 WorldXf   : World					< string UIWidget = "None"; >;
	float4x4 ViewIXf   : ViewInverse			< string UIWidget = "None"; >;

	float3 Lamp0Pos : Position <
		string Object = "PointLight0";
		string UIName = "Lamp 0 Position";
		string Space = "World";
	> = { -0.5f, 2.0f, 1.25f };

	float3 Lamp0Color : Specular <
		string UIName = "Lamp 0 Color";
		string Object = "Pointlight0";
		string UIWidget = "Color";
	> = { 1.0f, 1.0f, 1.0f };

	// These attributes mean a WOODEN Log, not a Logarithm!
	//	They define the relative size of the log to the model.
	float WoodScale <
		string UIWidget = "slider";
		float UIMin = 0.01;
		float UIMax = 20.0;
		float UIStep = 0.01;
		string UIName = "Model Size, Relative to Wood";
	> = 8;

	float WOffX <
		string UIWidget = "slider";
		float UIMin = -20.0;
		float UIMax = 20.0;
		float UIStep = 0.01;
		string UIName = "X Log-Center Offset";
	> = -10.0;

	float WOffY <
		string UIWidget = "slider";
		float UIMin = -20.0;
		float UIMax = 20.0;
		float UIStep = 0.01;
		string UIName = "Y Log-Center Offset";
	> = -11.0;

	float WOffZ <
		string UIWidget = "slider";
		float UIMin = -20.0;
		float UIMax = 20.0;
		float UIStep = 0.01;
		string UIName = "Z Log-Center Offset";
	> = 7.0;

	static float3 WoodOffset = (float3(WOffX, WOffY, WOffZ));
}

cbuffer CBufferPerFrame
{
	float3 AmbiColor : Ambient <
		string UIName = "Ambient Light";
		string UIWidget = "Color";
	> = { 0.17f, 0.17f, 0.17f };

	float3 WoodColor1 <
		string UIName = "Lighter Wood";
		string UIWidget = "Color";
	> = { 0.85f, 0.55f, 0.01f };

	float Ks1 <
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 2.0;
		float UIStep = 0.01;
		string UIName = "Lighter Wood Specularity";
	> = 0.5;

	// values for "darker" bands"

	float3 WoodColor2 <
		string UIName = "Darker Wood";
		string UIWidget = "Color";
	> = { 0.60f, 0.41f, 0.0f };

	float Ks2 <
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 2.0;
		float UIStep = 0.01;
		string UIName = "Darker Wood Specularity";
	> = 0.7;

	float SpecExpon <
		string UIWidget = "slider";
		float UIMin = 1.0;
		float UIMax = 128.0;
		float UIStep = 1.0;
		string UIName = "Specular Exponent";
	> = 30.0;

	float RingScale <
		string units = "inch";
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 10.0;
		float UIStep = 0.01;
		string UIName = "Ring Scale";
	> = 0.46;

	float AmpScale <
		string UIWidget = "slider";
		float UIMin = 0.01;
		float UIMax = 2.0;
		float UIStep = 0.01;
		string UIName = "Wobbliness";
	> = 0.7;

	float NoiseScale <
		string UIWidget = "slider";
		float UIMin = 0.01;
		float UIMax = 100.0;
		float UIStep = 0.01;
		string UIName = "Size of Noise Features";
	> = 32.0;
}

Texture3D Noise3DTex <
	string ResourceName = "noiseL8_32x32x32.dds";
	string UIName = "3D Noise Texture";
	string ResourceType = "3D";
>;

SamplerState NoiseSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
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
	float3 WoodPos			: TEXCOORD0; // wood grain coordinate system
	float3 LightVec			: TEXCOORD1;
	float3 WorldView		: TEXCOORD2;
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
	OUT.WorldView = normalize(ViewIXf[3].xyz - Pw);

	OUT.WoodPos = (WoodScale * Po.xyz) + WoodOffset; // wood grain coordinate system

	return OUT;
}

/************* Pixel Shader *************/

float4 pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float3 Hn = normalize(IN.WorldView + IN.LightVec);
	float hdn = dot(Hn, IN.WorldNormal);
	float ldn = dot(IN.LightVec, IN.WorldNormal);
	float4 litV = lit(ldn, hdn, SpecExpon);

	float3 noiseval = Noise3DTex.Sample(NoiseSampler, IN.WoodPos.xyz / NoiseScale).xyz;
	float3 Pwood = IN.WoodPos + (AmpScale * noiseval);
	float r = RingScale * sqrt(dot(Pwood.yz, Pwood.yz));
	r = r + Noise3DTex.Sample(NoiseSampler, r.xxx / 32.0).x;
	r = r - floor(r);
	r = smoothstep(0.0, 0.8, r) - smoothstep(0.83, 1.0, r);

	float3 dColor = lerp(WoodColor1, WoodColor2, r);
	float Ks = lerp(Ks1, Ks2, r);

	float3 diffContrib = dColor * ((litV.y * Lamp0Color) + AmbiColor);
	float3 specContrib = Ks * litV.z * Lamp0Color;
	float3 result = diffContrib + specContrib;
	return float4(result, 1);
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
