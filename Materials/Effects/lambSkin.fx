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
}

cbuffer CBufferPerFrame
{
	float3 AmbiColor : Ambient <
		string UIName = "Ambient Light";
		string UIWidget = "Color";
	> = { 0.07f, 0.07f, 0.07f };

	float3 DiffColor <
		string UIWidget = "Color";
		string UIName = "Surface Diffuse";
	> = { 0.9f, 1.0f, 0.9f };

	float3 SubColor <
		string UIWidget = "Color";
		string UIName = "Subsurface 'Bleed-thru'";
	> = { 1.0f, 0.2f, 0.2f };

	float RollOff <
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 0.99;
		float UIStep = 0.01;
		string UIName = "Subsurface Rolloff Range";
	> = 0.2;
}

Texture2D ColorTexture : DIFFUSE <
	string ResourceName = "DefaultColor.dds";
	string UIName = "Diffuse Texture";
	string ResourceType = "2D";
>;

SamplerState ColorSampler
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

struct lambVS_OUTPUT
{
	float4 HPosition		: SV_Position;
	float2 UV				: TEXCOORD0;
	float4 DColor			: COLOR0;
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
	OUT.LightVec = normalize(Lamp0Pos - Pw);
#ifdef FLIP_TEXTURE_Y
	OUT.UV = float2(IN.UV.x, (1.0 - IN.UV.y));
#else
	OUT.UV = IN.UV;
#endif
	OUT.WorldView = normalize(ViewIXf[3].xyz - Pw);

	return OUT;
}

void lambskin(float3 N,
	float3 L,
	out float3 Diffuse,
	out float3 Subsurface
	)
{
	float ldn = dot(L, N);
	float diffComp = max(0, ldn);
	Diffuse = diffComp * DiffColor;
	float subLamb = smoothstep(-RollOff, 1.0, ldn) - smoothstep(0.0, 1.0, ldn);
	subLamb = max(0.0, subLamb);
	Subsurface = subLamb * SubColor;
}

lambVS_OUTPUT lamb_vertex_shader(VS_INPUT IN)
{
	lambVS_OUTPUT OUT = (lambVS_OUTPUT)0;

	float4 Po = float4(IN.Position.xyz, 1.0);
	OUT.HPosition = mul(Po, WvpXf);

#ifdef FLIP_TEXTURE_Y
	OUT.UV = float2(IN.UV.x, (1.0 - IN.UV.y));
#else
	OUT.UV = IN.UV;
#endif
	float3 Pw = mul(Po, WorldXf).xyz;

	float3 worldN = normalize(mul(float4(IN.Normal, 0), WorldITXf).xyz);
	float3 lightV = normalize(Lamp0Pos - Pw);
	float3 diffContrib;
	float3 subContrib;
	lambskin(worldN, lightV, diffContrib, subContrib);
	OUT.DColor.rgb = diffContrib + AmbiColor + subContrib;
	OUT.DColor.a = 1.0;

	return OUT;
}

/************* Pixel Shader *************/

void lamb_shared(VS_OUTPUT IN,
	out float3 DiffuseContrib,
	out float3 SubContrib)
{
	lambskin(IN.WorldNormal, IN.LightVec, DiffuseContrib, SubContrib);
}

float4 lamb_pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float3 diffContrib;
	float3 subContrib;
	lamb_shared(IN, diffContrib, subContrib);
	float3 litC = diffContrib + AmbiColor + subContrib;
	return float4(litC.rgb, 1);
}

float4 lamb_pixel_shader_t(VS_OUTPUT IN) : SV_Target
{
	float3 diffContrib;
	float3 subContrib;
	lamb_shared(IN, diffContrib, subContrib);
	float3 litC = diffContrib + AmbiColor + subContrib;
	float4 T = ColorTexture.Sample(ColorSampler, IN.UV);
	return float4(litC.rgb * T.rgb, T.a);
}

float4 pixel_shader(lambVS_OUTPUT IN) : SV_Target
{
	return IN.DColor;
}

float4 pixel_shader_t(lambVS_OUTPUT IN) : SV_Target
{
	float4 result = IN.DColor * ColorTexture.Sample(ColorSampler, IN.UV);
	return float4(result.rgb, 1);
}

RasterizerState DisableCulling
{
	CullMode = NONE;
};

/************* Techniques *************/

technique11 TexturedPS
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, lamb_pixel_shader_t()));

		SetRasterizerState(DisableCulling);
	}
}

technique11 UntexturedPS
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, lamb_pixel_shader()));

		SetRasterizerState(DisableCulling);
	}
}

technique11 TexturedVS
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, lamb_vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, pixel_shader_t()));

		SetRasterizerState(DisableCulling);
	}
}

technique11 UntexturedVS
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, lamb_vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, pixel_shader()));

		SetRasterizerState(DisableCulling);
	}
}
