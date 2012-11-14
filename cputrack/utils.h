#pragma once

#include "std_incl.h" 

#include <string>
#include <vector>
#include <algorithm>
#include <cstdio>
#include <stdexcept>
#include <cassert>
#include <cmath>
#include <cstdlib>
#include <cstddef>

DLL_EXPORT void dbgout(std::string s);
DLL_EXPORT std::string SPrintf(const char *fmt, ...);
DLL_EXPORT void dbgprintf(const char *fmt,...);

template<typename T>
void DeleteAllElems(T& c) {
	for(typename T::iterator i=c.begin();i!=c.end();++i)
		delete *i;
	c.clear();
}

void floatToNormalizedUShort(ushort* dst, float *src, uint w,uint h);
ushort* floatToNormalizedUShort(float *data, uint w,uint h);

template<typename TPixel>
void normalize(TPixel* d, uint w,uint h)
{
	TPixel maxv = d[0];
	TPixel minv = d[0];
	for (uint k=0;k<w*h;k++) {
		maxv = std::max(maxv, d[k]);
		minv = std::min(minv, d[k]);
	}
	for (uint k=0;k<w*h;k++)
		d[k]=(d[k]-minv)/(maxv-minv);
}

void GenerateTestImage(float* data, int w, int h, float xp, float yp, float size, float MaxPhotons);
void ComputeRadialProfile(float* dst, int radialSteps, int angularSteps, float minradius, float maxradius,
	vector2f center, float* srcImage, int width, int height);


const inline float interp(float a, float b, float x) { return a + (b-a)*x; }

inline float Interpolate(float* image, int width, int height, float x,float y)
{
	int rx=x, ry=y;
	float v00 = image[width*ry+rx];
	float v10 = image[width*ry+rx+1];
	float v01 = image[width*(ry+1)+rx];
	float v11 = image[width*(ry+1)+rx+1];

	float v0 = interp (v00, v10, x-rx);
	float v1 = interp (v01, v11, x-rx);

	return interp (v0, v1, y-ry);
}
