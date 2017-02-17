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

	float FilmDepth <
		string UIName = "Film Thickness";
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 0.25;
		float UIStep = 0.001;
	> = 0.05f;
}

cbuffer CBufferPerFrame
{
	float3 SurfaceColor : DIFFUSE <
		string UIName = "Surface";
		string UIWidget = "Color";
	> = { 1, 1, 1 };

	float SpecExpon <
		string UIWidget = "slider";
		float UIMin = 1.0;
		float UIMax = 128.0;
		float UIStep = 1.0;
		string UIName = "Specular Exponent";
	> = 12.0;
}

Texture2D FringeMap <
	string ResourceName = "ColorRamp01.png";
	string UIName = "Thinfilm Gradient";
	string ResourceType = "2D";
>;

SamplerState FringeMapSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

/************* Data Structures *************/

struct VS_INPUT
{
	float3 Position	: POSITION;
	float3 Normal	: NORMAL;
};

struct VS_OUTPUT
{
	float4 HPosition		: SV_Position;
	float2 filmDepth		: TEXCOORD0;
	float3 DColor			: COLOR0;
	float3 SColor			: COLOR1;
};

/************* Vertex Shader *************/

float calc_view_depth(float NDotV, float Thickness)
{
	return (Thickness / NDotV);
}

VS_OUTPUT vertex_shader(VS_INPUT IN)
{
	VS_OUTPUT OUT = (VS_OUTPUT)0;

	float4 Po = float4(IN.Position.xyz, 1.0);
	OUT.HPosition = mul(Po, WvpXf);

	float3 Pw = mul(Po, WorldXf).xyz;
	float3 Ln = normalize(Lamp0Pos - Pw);
	float3 Vn = normalize(ViewIXf[3].xyz - Pw);
	float3 Hn = normalize(Ln + Vn);

	float3 Nn = mul(float4(IN.Normal, 0), WorldITXf).xyz;
	float ldn = dot(Ln, Nn);
	float hdn = dot(Hn, Nn);
	float vdn = dot(Vn, Nn);

	float4 litV = lit(ldn, hdn, SpecExpon);
	OUT.DColor = litV.yyy;
	OUT.SColor = pow(abs(hdn), SpecExpon).xxx;
	// compute the view depth for the thin film
	float viewdepth = calc_view_depth(vdn, FilmDepth.x);
	OUT.filmDepth = viewdepth.xx;

	return OUT;
}

/************* Pixel Shader *************/

float4 pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float3 fringeCol = FringeMap.Sample(FringeMapSampler, IN.filmDepth).rgb;
	// modulate specular lighting by fringe color, combine with regular lighting
	float3 result = fringeCol * IN.SColor + IN.DColor * SurfaceColor;
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
