module stk.instrument;

import stk.stk;

/**

STK instrument abstract base class.

This class provides a common interface for
all STK instruments.

Porting portions of STK library to D.
https://github.com/thestk/stk by Perry R. Cook and Gary P. Scavone, 1995--2016.

*/

abstract class Instrmnt : Stk
{
public:
    //! Class constructor.
    this() {
        lastFrame_.resize( 1, 1, 0.0 );
    };

    //! Reset and clear all internal state (for subclasses).
    /*!
    Not all subclasses implement a clear() function.
    */
    void clear() {};

    //! Start a note with the given frequency and amplitude.
    void noteOn( StkFloat frequency, StkFloat amplitude ) = 0;

    //! Stop a note with the given amplitude (speed of decay).
    void noteOff( StkFloat amplitude ) = 0;

    //! Set instrument parameters for a particular frequency.
    void setFrequency( StkFloat frequency );

    //! Perform the control change specified by \e number and \e value (0.0 - 128.0).
    void controlChange(int number, StkFloat value);

    //! Return the number of output channels for the class.
    uint channelsOut() const { return lastFrame_.channels(); };

    //! Return an StkFrames reference to the last output sample frame.
    ref StkFrames lastFrame() { return lastFrame_; };

    //! Return the specified channel value of the last computed frame.
    /*!
    The \c channel argument must be less than the number of output
    channels, which can be determined with the channelsOut() function
    (the first channel is specified by 0).  However, range checking is
    only performed if _STK_DEBUG_ is defined during compilation, in
    which case an out-of-range value will trigger an StkError
    exception. \sa lastFrame()
    */
    StkFloat lastOut( uint channel = 0 );

    //! Compute one sample frame and return the specified \c channel value.
    /*!
    For monophonic instruments, the \c channel argument is ignored.
    */
    StkFloat tick( uint channel = 0 ) = 0;

    //! Fill the StkFrames object with computed sample frames, starting at the specified channel.
    /*!
    The \c channel argument plus the number of output channels must
    be less than the number of channels in the StkFrames argument (the
    first channel is specified by 0).  However, range checking is only
    performed if _STK_DEBUG_ is defined during compilation, in which
    case an out-of-range value will trigger an StkError exception.
    */
    StkFrames tick( StkFrames frames, uint channel = 0) = 0;

protected:

    StkFrames lastFrame_;

}
