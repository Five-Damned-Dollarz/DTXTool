import std.stdio;
import std.getopt;
import std.path: setExtension;
import dimage;

enum DTXVersion=-2;

enum DTXFlags : uint
{
	FullBrite=1,
	AlphaMasks=2,
	Unknown1=4,
	Unknown2=8
}

struct DTXHeader
{
	int id;
	int version_;
	ushort width;
	ushort height;
	ushort mipmap_count;
	ushort has_lights;
	DTXFlags flags;
	uint flags_other;
	ubyte group;
	ubyte mipmaps_used_count; // 0 = 4?
	ubyte alpha_cutoff; // seems to be limited to [128-255]
	ubyte alpha_average;
	uint unknown_1;
	uint unknown_2;
	ubyte unknown_3;
	ubyte unknown_4;
	ushort unknown_5;
	ubyte unknown_6;
	ubyte unknown_7;
	ushort unknown_8;
}

void main(string[] args)
{
	string filename_in;
	string filename_out;

	auto cmd_args=getopt(args,
		"in|i", "Input filename", &filename_in,
		"out|o", "(optional) Output filename", &filename_out);

	if (cmd_args.helpWanted || !filename_in)
	{
		defaultGetoptPrinter("Convert 8-bit index PNG to Lithtech 1.0 DTX", cmd_args.options);
		return;
	}

	if (!filename_out)
		filename_out=filename_in.setExtension("dtx");

	File file_in;

	try
	{
		file_in.open(filename_in, "rb");
	}
	catch(Exception e)
	{
		writeln(e.msg);
		return;
	}

	Image texture=PNG.load(file_in);

	if (!texture.isIndexed)
	{
		writeln("Input image doesn't have a palette.");
		return;
	}

	if (texture.getBitdepth!=8)
	{
		writeln("Input image doesn't use 8 bit index.");
		return;
	}

	if (texture.palette.length!=256) // TODO: check for more than 256, and autopad less than
	{
		writeln("Input image doesn't have 256 palette entries.");
		return;
	}

	File test_out=File(filename_out, "wb");

	DTXHeader header={
		version_: DTXVersion,
		width: cast(ushort)texture.width,
		height: cast(ushort)texture.height,
		mipmap_count: 4,
		has_lights: 0,
		flags: DTXFlags.Unknown2,
		group: 0,
		mipmaps_used_count: 1
	};

	test_out.rawWrite!DTXHeader([header]);
	test_out.rawWrite(texture.palette.convTo(PixelFormat.XRGB8888|PixelFormat.BigEndian).raw);
	test_out.rawWrite(texture.imageData.raw);

	// write 2nd, 3rd, and 4th mipmaps
	// TODO: make real mipmaps
	for(int i=1; i<header.mipmap_count; ++i)
	{
		for(int y=0; y<texture.height >> i; ++y)
		{
			for(int x=0; x<texture.width >> i; ++x)
			{
				test_out.rawWrite!ubyte([0]);
			}
		}
	}

	// write 4-bit alpha maps
	// TODO: write real alpha
	if (header.flags & DTXFlags.AlphaMasks)
	{
		for(int i=1; i<header.mipmap_count; ++i)
		{
			for(int y=0; y<texture.height >> i; ++y)
			{
				for(int x=0; x<texture.width/2 >> i; ++x)
				{
					test_out.rawWrite!ubyte([0xFF]);
				}
			}
		}
	}

	if (header.has_lights)
	{
		// TODO: write lights
		test_out.rawWrite("LIGHTDEFS");
	}
}