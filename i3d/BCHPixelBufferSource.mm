/*
 
 Video Core
 Copyright (c) 2014 James G. Hurley
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#include "BCHPixelBufferSource.h"
#include <videocore/mixers/IVideoMixer.hpp>

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

namespace BCH { namespace iOS {
    
    PixelBufferSource::PixelBufferSource(float x,
                               float y,
                               float w,
                               float h,
                               float vw,
                               float vh,
                               float aspect)
    : m_size({x,y,w,h,vw,vh,w/h}),
    m_targetSize(m_size),
    m_captureDevice(NULL),
    m_isFirst(true),
    m_callbackSession(NULL),
    m_aspectMode(kAspectFit),
    m_fps(15),
    m_usingDeprecatedMethods(true)
    {}
    
    PixelBufferSource::PixelBufferSource()
    :
    m_captureDevice(nullptr),
    m_callbackSession(nullptr),
    m_matrix(glm::mat4(1.f)),
    m_usingDeprecatedMethods(false)
    {}
    
    PixelBufferSource::~PixelBufferSource()
    {
        [[NSNotificationCenter defaultCenter] removeObserver:(id)m_callbackSession];
        [((AVCaptureSession*)m_captureSession) stopRunning];
        [((AVCaptureSession*)m_captureSession) release];
    }

    void
    PixelBufferSource::setAspectMode(AspectMode aspectMode)
    {
        m_aspectMode = aspectMode;
        m_isFirst = true;           // Force the transformation matrix to be re-generated.
    }
    void
    PixelBufferSource::setOutput(std::shared_ptr<videocore::IOutput> output)
    {
        m_output = output;
        
        auto mixer = std::static_pointer_cast<videocore::IVideoMixer>(output);
    }
    void
    PixelBufferSource::bufferCaptured(CVPixelBufferRef pixelBufferRef)
    {
        auto output = m_output.lock();
        if(output) {
            
            if(m_usingDeprecatedMethods && m_isFirst) {
                
                m_isFirst = false;
                
                m_size.w = float(CVPixelBufferGetWidth(pixelBufferRef));
                m_size.h = float(CVPixelBufferGetHeight(pixelBufferRef));
                
                const float wfac = m_targetSize.w / m_size.w;
                const float hfac = m_targetSize.h / m_size.h;
                
                const float mult = (m_aspectMode == kAspectFit ? (wfac < hfac) : (wfac > hfac)) ? wfac : hfac;
                
                m_size.w *= mult;
                m_size.h *= mult;
                
                glm::mat4 mat(1.f);
                
                mat = glm::translate(mat,
                                     glm::vec3((m_size.x / m_targetSize.vw) * 2.f - 1.f,   // The compositor uses normalized device co-ordinates.
                                               (m_size.y / m_targetSize.vh) * 2.f - 1.f,   // i.e. [ -1 .. 1 ]
                                               0.f));
                
                mat = glm::scale(mat,
                                 glm::vec3(m_size.w / m_targetSize.vw, //
                                           m_size.h / m_targetSize.vh, // size is a percentage for scaling.
                                           1.f));
                
                m_matrix = mat;
            }

            
            videocore::VideoBufferMetadata md(1.f / float(m_fps));
            
            md.setData(1, m_matrix, shared_from_this());
            
            CVPixelBufferRetain(pixelBufferRef);
            output->pushBuffer((uint8_t*)pixelBufferRef, sizeof(pixelBufferRef), md);
            CVPixelBufferRelease(pixelBufferRef);
        }
    }
    
}
}
