module stk.twozero;

import stk.filter;

/***************************************************/
/*! \class TwoZero
\brief STK two-zero filter class.

This class implements a two-zero digital filter.  A method is
provided for creating a "notch" in the frequency response while
maintaining a constant filter gain.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

class TwoZero : Filter
{
public:
    //! Default constructor creates a second-order pass-through filter.
    this() {
        b_.length = 3;
        b_[0 .. $] = 0;
        inputs_.resize( 3, 1, 0.0 );
        b_[0] = 1.0;
        Stk.addSampleRateAlert( this );
    }

    //! Class destructor.
    ~this() {
        Stk.removeSampleRateAlert( this );
    }

    //! A function to enable/disable the automatic updating of class data when the STK sample rate changes.
    override void ignoreSampleRateChange( bool ignore = true ) { ignoreSampleRateChange_ = ignore; };

    //! Set the b[0] coefficient value.
    void setB0( StkFloat b0 ) { b_[0] = b0; };

    //! Set the b[1] coefficient value.
    void setB1( StkFloat b1 ) { b_[1] = b1; };

    //! Set the b[2] coefficient value.
    void setB2( StkFloat b2 ) { b_[2] = b2; };

    //! Set all filter coefficients.
    void setCoefficients( StkFloat b0, StkFloat b1, StkFloat b2, bool clearState = false ) {
        b_[0] = b0;
        b_[1] = b1;
        b_[2] = b2;

        if ( clearState ) this.clear();
    }

    //! Sets the filter coefficients for a "notch" at \e frequency (in Hz).
    /*!
    This method determines the filter coefficients corresponding to
    two complex-conjugate zeros with the given \e frequency (in Hz)
    and \e radius from the z-plane origin.  The coefficients are then
    normalized to produce a maximum filter gain of one (independent of
    the filter \e gain parameter).  The resulting filter frequency
    response has a "notch" or anti-resonance at the given \e
    frequency.  The closer the zeros are to the unit-circle (\e radius
    close to or equal to one), the narrower the resulting notch width.
    The \e frequency value should be between zero and half the sample
    rate.  The \e radius value should be positive.
    */
    void setNotch( StkFloat frequency, StkFloat radius ) {
        b_[2] = radius * radius;
        b_[1] = -2.0 * radius * cos(TWO_PI * frequency / Stk.sampleRate());

        // Normalize the filter gain.
        if ( b_[1] > 0.0 ) // Maximum at z = 0.
            b_[0] = 1.0 / ( 1.0 + b_[1] + b_[2] );
        else            // Maximum at z = -1.
            b_[0] = 1.0 / ( 1.0 - b_[1] + b_[2] );
        b_[1] *= b_[0];
        b_[2] *= b_[0];
    }

    //! Return the last computed output value.
    StkFloat lastOut() const { return lastFrame_[0]; };

    //! Input one sample to the filter and return one output.
    StkFloat tick( StkFloat input ) {
        inputs_[0] = gain_ * input;
        lastFrame_[0] = b_[2] * inputs_[2] + b_[1] * inputs_[1] + b_[0] * inputs_[0];
        inputs_[2] = inputs_[1];
        inputs_[1] = inputs_[0];

        return lastFrame_[0];
    }

    //! Take a channel of the StkFrames object as inputs to the filter and replace with corresponding outputs.
    /*!
    The StkFrames argument reference is returned.  The \c channel
    argument must be less than the number of channels in the
    StkFrames argument (the first channel is specified by 0).
    However, range checking is only performed if _STK_DEBUG_ is
    defined during compilation, in which case an out-of-range value
    will trigger an StkError exception.
    */
    ref StkFrames tick( ref StkFrames frames, uint channel = 0 ) {
        StkFloat *samples = &frames[channel];
        uint hop = frames.channels();
        for ( uint i=0; i<frames.frames(); i++, samples += hop ) {
            inputs_[0] = gain_ * *samples;
            *samples = b_[2] * inputs_[2] + b_[1] * inputs_[1] + b_[0] * inputs_[0];
            inputs_[2] = inputs_[1];
            inputs_[1] = inputs_[0];
        }

        lastFrame_[0] = *(samples-hop);
        return frames;
    }

    //! Take a channel of the \c iFrames object as inputs to the filter and write outputs to the \c oFrames object.
    /*!
    The \c iFrames object reference is returned.  Each channel
    argument must be less than the number of channels in the
    corresponding StkFrames argument (the first channel is specified
    by 0).  However, range checking is only performed if _STK_DEBUG_
    is defined during compilation, in which case an out-of-range value
    will trigger an StkError exception.
    */
    ref StkFrames tick( ref StkFrames iFrames, ref StkFrames oFrames, uint iChannel = 0, uint oChannel = 0 ) {
        StkFloat *iSamples = &iFrames[iChannel];
        StkFloat *oSamples = &oFrames[oChannel];
        uint iHop = iFrames.channels(), oHop = oFrames.channels();
        for ( uint i=0; i<iFrames.frames(); i++, iSamples += iHop, oSamples += oHop ) {
            inputs_[0] = gain_ * *iSamples;
            *oSamples = b_[2] * inputs_[2] + b_[1] * inputs_[1] + b_[0] * inputs_[0];
            inputs_[2] = inputs_[1];
            inputs_[1] = inputs_[0];
        }

        lastFrame_[0] = *(oSamples-oHop);
        return iFrames;
    }

protected:

    override void sampleRateChanged( StkFloat newRate, StkFloat oldRate ) {
        if ( !ignoreSampleRateChange_ ) {
            //oStream_ << "TwoZero::sampleRateChanged: you may need to recompute filter coefficients!";
            handleError( StkErrorType.WARNING );
        }
    }
};

