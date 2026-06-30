/*
 * AudioWeb.cpp - Web Audio API backend for LMMS WebAssembly
 *
 * Copyright (c) 2024 LMMS WASM contributors
 *
 * This file is part of LMMS - https://lmms.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING. If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Uses ScriptProcessorNode to deliver rendered audio to browser output.
 * Audio callbacks come from JavaScript -> lmms_web_audio_render().
 */

#include "AudioWeb.h"

#include <algorithm>
#include <cstdio>

#ifdef LMMS_HAVE_WEB_AUDIO
#include <emscripten.h>
#endif

namespace lmms
{

#ifdef LMMS_HAVE_WEB_AUDIO

static AudioWeb* g_audioWebInstance = nullptr;
static AudioEngine* g_webEngine = nullptr;

// Called from JavaScript audio callback via ScriptProcessorNode
extern "C" {

EMSCRIPTEN_KEEPALIVE
void lmms_web_audio_render(float* outL, float* outR, int numFrames)
{
	if (!g_audioWebInstance || !g_webEngine) return;
	if (!g_audioWebInstance->AudioDevice::isRunning()) return;

	const f_cnt_t periodSize = g_webEngine->framesPerPeriod();
	for (int offset = 0; offset < numFrames; offset += static_cast<int>(periodSize))
	{
		const int frames = std::min<int>(
			static_cast<int>(periodSize), numFrames - offset);
		auto period = g_webEngine->renderNextPeriod();
		for (int i = 0; i < frames; ++i) {
			outL[offset + i] = period[i][0];
			outR[offset + i] = period[i][1];
		}
	}
}

EMSCRIPTEN_KEEPALIVE
const char* lmms_web_get_sample_rate()
{
	if (!g_audioWebInstance) return "44100";
	static char buf[16];
	std::snprintf(buf, sizeof(buf), "%d", g_audioWebInstance->sampleRate());
	return buf;
}

EMSCRIPTEN_KEEPALIVE
int lmms_web_get_frames_per_period()
{
	if (!g_webEngine) return 256;
	return static_cast<int>(g_webEngine->framesPerPeriod());
}

} // extern "C"

AudioWeb::AudioWeb(bool& _success_ful, AudioEngine* engine) :
	AudioDevice(DEFAULT_CHANNELS, engine)
{
	_success_ful = true;
	g_audioWebInstance = this;
	g_webEngine = engine;
}

AudioWeb::~AudioWeb()
{
	g_audioWebInstance = nullptr;
	g_webEngine = nullptr;
	stopProcessing();
}

void AudioWeb::startProcessingImpl()
{
	start();
}

void AudioWeb::stopProcessingImpl()
{
	stopProcessingThread(this);
}

void AudioWeb::run()
{
	// Audio processing is driven by JavaScript audio callbacks.
	// This thread keeps the Qt event loop running so the UI stays responsive.
	exec();
}

#endif // LMMS_HAVE_WEB_AUDIO

} // namespace lmms
