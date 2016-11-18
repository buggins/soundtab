module stk.generator;

public import stk.stk;

/***************************************************/
/*! \class Generator
\brief STK abstract unit generator parent class.

This class provides limited common functionality for STK unit
generator sample-source subclasses.  It is general enough to
support both monophonic and polyphonic output classes.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

abstract class Generator : Stk
{
    //! Class constructor.
    this() { lastFrame_.resize( 1, 1, 0.0 ); }

    //! Return the number of output channels for the class.
    uint channelsOut() const {
        return lastFrame_.channels();
    }

    //! Return an StkFrames reference to the last output sample frame.
    ref StkFrames lastFrame() {
        return lastFrame_;
    }

    //! Fill the StkFrames object with computed sample frames, starting at the specified channel.
    /*!
    The \c channel argument plus the number of output channels must
    be less than the number of channels in the StkFrames argument (the
    first channel is specified by 0).  However, range checking is only
    performed if _STK_DEBUG_ is defined during compilation, in which
    case an out-of-range value will trigger an StkError exception.
    */
    //ref StkFrames tick( ref StkFrames frames, uint channel = 0 ) = 0;

protected:

    StkFrames lastFrame_;
}
