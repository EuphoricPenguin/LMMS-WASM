/*
 * AudioWeb.h - Web Audio API backend for LMMS WebAssembly
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
 */

#ifndef LMMS_AUDIO_WEB_H
#define LMMS_AUDIO_WEB_H

#include "AudioDevice.h"
#include "AudioDeviceSetupWidget.h"
#include "AudioEngine.h"

namespace lmms
{

class AudioWeb : public QThread, public AudioDevice
{
	Q_OBJECT
public:
	AudioWeb( bool & _success_ful, AudioEngine* audioEngine );
	~AudioWeb() override;

	inline static QString name()
	{
		return QT_TRANSLATE_NOOP( "AudioDeviceSetupWidget", "Web Audio (WASM)" );
	}

	class setupWidget : public gui::AudioDeviceSetupWidget
	{
	public:
		setupWidget( QWidget * _parent ) :
			gui::AudioDeviceSetupWidget( AudioWeb::name(), _parent )
		{
		}
		~setupWidget() override = default;
		void saveSettings() override {}
		void show() override
		{
			parentWidget()->hide();
			QWidget::show();
		}
	};

private:
	void startProcessingImpl() override;
	void stopProcessingImpl() override;
	void run() override;

	AudioEngine* m_audioEngine;
};

} // namespace lmms

#endif // LMMS_AUDIO_WEB_H
