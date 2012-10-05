
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <cassert>
#include <cstdlib>
#include <stdio.h>
#include <windows.h>
#include <cstdarg>

#include "../cudatrack/utils.h"
#include "../cudatrack/Array2D.h"

#include <thrust/functional.h>

#include "../cudatrack/tracker.h"

#include "nivision.h" // write PNG file

#include "../cudatrack/LsqQuadraticFit.h"

using namespace gpuArray;

static DWORD startTime = 0;
void BeginMeasure() { startTime = GetTickCount(); }
DWORD EndMeasure(const std::string& msg) {
	DWORD endTime = GetTickCount();
	DWORD dt = endTime-startTime;
	dbgout(SPrintf("%s: %d ms\n", msg.c_str(), dt));
	return dt;
}

void saveImage(Array2D<pixel_t, float>& img, const char* filename)
{
	pixel_t *norm = new pixel_t[img.w * img.h];
	img.copyToHost(norm);
	/*
	pixel_t maxv = data[0];
	pixel_t minv = data[0];
	for (int k=0;k<img.w*img.h;k++) {
		maxv = max(maxv, data[k]);
		minv = min(minv, data[k]);
	}
	ushort *norm = new ushort[img.w*img.h];
	for (int k=0;k<img.w*img.h;k++)
		norm[k] = ((1<<16)-1) * (data[k]-minv) / (maxv-minv);
		*/
	Image* dst = imaqCreateImage(IMAQ_IMAGE_U8, 0);
	imaqSetImageSize(dst, img.w, img.h);
	imaqArrayToImage(dst, norm, img.w, img.h);
	delete[] norm;

	ImageInfo info;
	imaqGetImageInfo(dst, &info);
	int success = imaqWriteFile(dst, filename, 0);
	if (!success) {
		char *errStr = imaqGetErrorText(imaqGetLastError());
		std::string msg = SPrintf("IMAQ WriteFile error: %s\n", errStr);
		imaqDispose(errStr);
		dbgout(msg);
	}
	imaqDispose(dst);
}

vector2f ComputeCOM(pixel_t* data, uint w,uint h)
{
	float sum=0.0f;
	float momentX=0.0f;
	float momentY=0.0f;

	for (uint y=0;y<h;y++)
		for(uint x=0;x<w;x++)
		{
			pixel_t v = data[y*w+x];
			sum += v;
			momentX += x*v;
			momentY += y*v;
		}
	vector2f com;
	com.x = momentX / sum;
	com.y = momentY / sum;
	return com;
}

void BenchmarkCOM(Tracker& tracker)
{
	int N=1000;
	DWORD dt;
	pixel_t* data = new pixel_t[tracker.width * tracker.height];
	tracker.copyToHost(data, sizeof(pixel_t)*tracker.width);
	pixel_t* tmp = new pixel_t[tracker.width * tracker.height];

	BeginMeasure();
	for (int k=0;k<N;k++)  {
		tracker.computeMedianPixelValue();
	}
	dt = EndMeasure("GPU Median");
	dbgout(SPrintf("GPU: %d medians per second\n", (int)(N * 1000 / dt)));

	BeginMeasure();
	for (int k=0;k<N;k++)  {
		memcpy(tmp, data, sizeof(pixel_t)*tracker.width*tracker.height);
		std::sort(tmp, tmp+(tracker.width*tracker.height));
	}
	dt = EndMeasure("CPU Median");
	dbgout(SPrintf("CPU: %d medians per second\n", (int)(N * 1000 / dt)));

	BeginMeasure();
	for (int k=0;k<N;k++)  {
		vector2f COM = tracker.computeCOM();
	}
	dt = EndMeasure("GPU COM");
	dbgout(SPrintf("GPU: %d COMs per second\n", (int)(N * 1000 / dt)));

	BeginMeasure();
	for (int k=0;k<N;k++)  {
		vector2f COM = ComputeCOM(data, tracker.width, tracker.height);
	}
	dt = EndMeasure("CPU COM");
	dbgout(SPrintf("CPU: %d COMs per second\n", (int)(N * 1000 / dt)));
	delete[] data;
	delete[] tmp;
}



std::string getPath(const char *file)
{
	std::string s = file;
	int pos = s.length()-1;
	while (pos>0 && s[pos]!='\\' && s[pos]!= '/' )
		pos--;
	
	return s.substr(0, pos);
}

int main(int argc, char *argv[])
{
//	testLinearArray();

	std::string path = getPath(argv[0]);

	Tracker tracker(150,150);

	tracker.loadTestImage(5,5, 1);
	
	Array2D<float> tmp(10,2);
	float *tmpdata=new float[tmp.w*tmp.h];
	float sumCPU=0.0f;
	for (int y=0;y<tmp.h;y++){
		for (int x=0;x<tmp.w;x++) {
			tmpdata[y*tmp.w+x]=x;
			sumCPU += x;
		}
	}
	tmp.set(tmpdata, sizeof(float)*tmp.w);

	float* checkmem=new float[tmp.w*tmp.h];
	tmp.copyToHost(checkmem);
	assert (memcmp(checkmem, tmpdata, sizeof(float)*tmp.w*tmp.h)==0);
	delete[] checkmem;

	delete[] tmpdata;
	reducer_buffer<float> rbuf(tmp.w,tmp.h);
	float sumGPU = tmp.sum(rbuf);
	dbgout(SPrintf("SumCPU: %f, SUMGPU: %f\n", sumCPU, sumGPU));
	
	BenchmarkCOM(tracker);

	Array2D<pixel_t, float>* data = (Array2D<pixel_t, float>*)tracker.getCurrentBufferImage();
	saveImage(*data, (path + "\\testImg.png").c_str());
	//dbgout(SPrintf("COM: %f, %f\n", COM.x,COM.y));
//	vector2f xcor = tracker.XCorLocalize(COM);

	float x[] = { -2, -1 , 0, 1, 2, 3,  };
	float y[sizeof(x)/sizeof(float)];
	for (int k=0;k<6;k++)
		y[k]=-x[k]*x[k]*2 + x[k]*4 - 10;
	
	LsqSqQuadFit<float> qfit(6, x, y);
	dbgout( SPrintf("A: %f, B: %f, C: %f. Max:%f\n", qfit.a, qfit.b, qfit.c, qfit.maxPos()));

	return 0;
}