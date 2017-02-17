/************* Resources *************/

cbuffer CBufferPerObject
{
	float4x4 WorldITXf : WorldInverseTranspose	< string UIWidget = "None"; >;
	float4x4 WvpXf     : WorldViewProjection	< string UIWidget = "None"; >;
	float4x4 WorldXf   : World					< string UIWidget = "None"; >;
	float4x4 ViewIXf   : ViewInverse			< string UIWidget = "None"; >;

	float Timer : TIME < string UIWidget = "None"; >;

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

	float Lamp0Intensity <
		string UIWidget = "slider";
		float UIMin = 1.0;
		float UIMax = 10000.0f;
		float UIStep = 0.1;
		string UIName = "Lamp 0 Quadratic Intensity";
	> = 1.0f;
}

cbuffer CBufferPerFrame
{
	float3 AmbiColor : Ambient <
		string UIName = "Ambient Light";
		string UIWidget = "Color";
	> = { 0.07f, 0.07f, 0.07f };

	float3 SurfaceColor : DIFFUSE <
		string UIName = "Surface";
		string UIWidget = "Color";
	> = { 1, 1, 1 };

	float Ks <
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 1.0;
		float UIStep = 0.05;
		string UIName = "Specular";
	> = 0.4;

	float SpecExpon <
		string UIWidget = "slider";
		float UIMin = 1.0;
		float UIMax = 128.0;
		float UIStep = 1.0;
		string UIName = "Specular Exponent";
	> = 30.0;

	float Oversample <
		string UIWidget = "slider";
		float uimin = 0.0;
		float uimax = 20.0;
		float uistep = 0.0001;
		string UIName = "AA Softness";
	> = 1.0;

	float Period <
		string UIWidget = "slider";
		float uimin = 0.0;
		float uimax = 1.0;
		float uistep = 0.001;
		string UIName = "Stripe Period";
	> = 0.5;

	float Balance <
		string UIWidget = "slider";
		float uimin = 0.01;
		float uimax = 0.99;
		float uistep = 0.01;
		string UIName = "Clip Balance";
	> = 0.5;

	float WaveFreq <
		string UIWidget = "slider";
		float uimin = 0.0;
		float uimax = 40.0;
		float uistep = 0.01;
		string UIName = "Wave Period";
	> = 7.0;

	float WaveGain <
		string UIWidget = "slider";
		float uimin = 0.0;
		float uimax = 1.0;
		float uistep = 0.01;
		string UIName = "Wobbliness";
	> = 0.2;

	float Speed <
		string UIWidget = "slider";
		float uimin = 0.0;
		float uimax = 10.0;
		float uistep = 0.01;
		string UIName = "Wave Speed";
	> = 2.5;
}

/************* Data Structures *************/

struct VS_INPUT
{
	float3 Position	: POSITION;
	float2 UV		: TEXCOORD0;
	float3 Normal	: NORMAL;
	float3 Tangent	: TANGENT;
	float3 Binormal : BINORMAL;
};

struct VS_OUTPUT
{
	float4 HPosition		: SV_Position;
	float3 WorldNormal		: NORMAL;
	float3 WorldTangent		: TANGENT;
	float3 WorldBinormal	: BINORMAL;
	float2 UV				: TEXCOORD0;
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
	OUT.WorldTangent = normalize(mul(float4(IN.Tangent, 0), WorldITXf).xyz);
	OUT.WorldBinormal = normalize(mul(float4(IN.Binormal, 0), WorldITXf).xyz);

	float3 Pw = mul(Po, WorldXf).xyz;
	OUT.LightVec = Lamp0Pos - Pw;
#ifdef FLIP_TEXTURE_Y
	OUT.UV = float2(IN.UV.x, (1.0 - IN.UV.y));
#else
	OUT.UV = IN.UV;
#endif
	OUT.WorldView = normalize(ViewIXf[3].xyz - Pw);

	return OUT;
}

/************* Pixel Shader *************/

float4 pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float wavy = WaveGain * sin(IN.UV.y * WaveFreq + (Speed * Timer));
	float balanced = (wavy + Balance);
	balanced = min(1.0, max(0.0, balanced));
	float edge = Period * balanced;
	float width = abs(ddx(IN.UV.x)) + abs(ddy(IN.UV.x));
	float w = width * Oversample / Period;
	float x0 = IN.UV.x / Period - (w / 2.0);
	float x1 = x0 + w;
	float nedge = edge / Period;
	float i0 = (1.0 - nedge) * floor(x0) + max(0.0, frac(x0) - nedge);
	float i1 = (1.0 - nedge) * floor(x1) + max(0.0, frac(x1) - nedge);
	float s = (i1 - i0) / w;
	s = min(1.0, max(0.0, s));

	float3 Ln = normalize(IN.LightVec);
	float falloff = Lamp0Intensity / dot(IN.LightVec, IN.LightVec);
	float ldn = dot(Ln, IN.WorldNormal);
	float diffComp = falloff * max(0, ldn);
	float3 diffC = (s * SurfaceColor) * ((diffComp * Lamp0Color) + AmbiColor);

	float3 Hn = normalize(IN.WorldView + Ln);
	float hdn = pow(max(0, dot(Hn, IN.WorldNormal)), SpecExpon);

	float3 specC = falloff * hdn * Lamp0Color;
	float3 result = diffC + ((1.0 - s) * Ks * specC);
	return float4(result.rgb, 1.0);
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
