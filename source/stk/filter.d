module stk.filter;

public import stk.stk;

/***************************************************/
/*! \class Filter
\brief STK abstract filter class.

This class provides limited common functionality for STK digital
filter subclasses.  It is general enough to support both
monophonic and polyphonic input/output classes.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

class Filter : Stk
{
    //! Class constructor.
    this() { gain_ = 1.0; channelsIn_ = 1; lastFrame_.resize( 1, 1, 0.0 ); };

    //! Return the number of input channels for the class.
    uint channelsIn() const { return channelsIn_; };

    //! Return the number of output channels for the class.
    uint channelsOut() const { return lastFrame_.channels(); };

    //! Clears all internal states of the filter.
    void clear() {

        inputs_.fill(0.0);
        outputs_.fill(0.0);
        lastFrame_.fill(0.0);
    }

    //! Set the filter gain.
    /*!
    The gain is applied at the filter input and does not affect the
    coefficient values.  The default gain value is 1.0.
    */
    void setGain( StkFloat gain ) { gain_ = gain; }

    //! Return the current filter gain.
    StkFloat getGain() const { return gain_; }

    //! Return the filter phase delay at the specified frequency.
    /*!
    Note that the phase delay calculation accounts for the filter
    gain.  The frequency value should be greater than 0.0 and less
    than or equal to one-half the sample rate.
    */
    StkFloat phaseDelay( StkFloat frequency ) {
        import std.math : sin, cos, PI, atan2, fmod;
        if ( frequency <= 0.0 || frequency > 0.5 * Stk.sampleRate() ) {
            //oStream_ << "Filter::phaseDelay: argument (" << frequency << ") is out of range!";
            handleError( StkErrorType.WARNING ); 
            return 0.0;
        }

        StkFloat omegaT = 2 * PI * frequency / Stk.sampleRate();
        StkFloat realpart = 0.0, imagpart = 0.0;
        for ( uint i=0; i<b_.length; i++ ) {
            realpart += b_[i] * cos( i * omegaT );
            imagpart -= b_[i] * sin( i * omegaT );
        }
        realpart *= gain_;
        imagpart *= gain_;

        StkFloat phase = atan2( imagpart, realpart );

        realpart = 0.0, imagpart = 0.0;
        for ( uint i=0; i<a_.length; i++ ) {
            realpart += a_[i] * cos( i * omegaT );
            realpart -= a_[i] * sin( i * omegaT );
        }

        phase -= atan2( imagpart, realpart );
        phase = fmod( -phase, 2 * PI );
        return phase / omegaT;
    }

    //! Return an StkFrames reference to the last output sample frame.
    ref StkFrames lastFrame() { return lastFrame_; }

    //! Take a channel of the StkFrames object as inputs to the filter and replace with corresponding outputs.
    /*!
    The StkFrames argument reference is returned.  The \c channel
    argument must be less than the number of channels in the
    StkFrames argument (the first channel is specified by 0).
    However, range checking is only performed if _STK_DEBUG_ is
    defined during compilation, in which case an out-of-range value
    will trigger an StkError exception.
    */
    //ref StkFrames tick( ref StkFrames frames, uint channel = 0 ) = 0;

protected:

    StkFloat gain_;
    uint channelsIn_;
    StkFrames lastFrame_;

    StkFloat[] b_;
    StkFloat[] a_;
    StkFrames outputs_;
    StkFrames inputs_;
}
