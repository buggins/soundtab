module stk.fm;

import stk.stk;
import stk.instrument;
import stk.adsr;
import stk.fileloop;
import stk.sinewave;
import stk.twozero;

/***************************************************/
/*! \class FM
\brief STK abstract FM synthesis base class.

This class controls an arbitrary number of
waves and envelopes, determined via a
constructor argument.

Control Change Numbers: 
- Control One = 2
- Control Two = 4
- LFO Speed = 11
- LFO Depth = 1
- ADSR 2 & 4 Target = 128

The basic Chowning/Stanford FM patent expired
in 1995, but there exist follow-on patents,
mostly assigned to Yamaha.  If you are of the
type who should worry about this (making
money) worry away.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

abstract class FM : Instrmnt
{
public:
    //! Class constructor, taking the number of wave/envelope operators to control.
    /*!
    An StkError will be thrown if the rawwave path is incorrectly set.
    */
    this( uint operators = 4 ) {
    }

    //! Class destructor.
    ~this() {
    }

    //! Load the rawwave filenames in waves.
    void loadWaves( const char **filenames ) {
    }

    //! Set instrument parameters for a particular frequency.
    override void setFrequency( StkFloat frequency ) {
    }

    //! Set the frequency ratio for the specified wave.
    void setRatio(uint waveIndex, StkFloat ratio) {
    }

    //! Set the gain for the specified wave.
    void setGain( uint waveIndex, StkFloat gain ) {
    }

    //! Set the modulation speed in Hz.
    void setModulationSpeed( StkFloat mSpeed ) { vibrato_.setFrequency( mSpeed ); };

    //! Set the modulation depth.
    void setModulationDepth( StkFloat mDepth ) { modDepth_ = mDepth; };

    //! Set the value of control1.
    void setControl1( StkFloat cVal ) { control1_ = cVal * 2.0; };

    //! Set the value of control1.
    void setControl2( StkFloat cVal ) { control2_ = cVal * 2.0; };

    //! Start envelopes toward "on" targets.
    void keyOn() {
    }

    //! Start envelopes toward "off" targets.
    void keyOff() {
    }

    //! Stop a note with the given amplitude (speed of decay).
    void noteOff( StkFloat amplitude ) {
    }

    //! Perform the control change specified by \e number and \e value (0.0 - 128.0).
    override void controlChange( int number, StkFloat value ) {
    }

    //! Compute and return one output sample.
    StkFloat tick( uint channel = 0) {
        return 0;
    }

    //! Fill a channel of the StkFrames object with computed outputs.
    /*!
    The \c channel argument must be less than the number of
    channels in the StkFrames argument (the first channel is specified
    by 0).  However, range checking is only performed if _STK_DEBUG_
    is defined during compilation, in which case an out-of-range value
    will trigger an StkError exception.
    */
    //ref StkFrames tick( ref StkFrames frames, uint channel = 0 ) = 0;

protected:

    ADSR[] adsr_; 
    FileLoop[] waves_;
    SineWave vibrato_;
    TwoZero  twozero_;
    uint nOperators_;
    StkFloat baseFrequency_;
    StkFloat[] ratios_;
    StkFloat[] gains_;
    StkFloat modDepth_;
    StkFloat control1_;
    StkFloat control2_;
    StkFloat[100] fmGains_;
    StkFloat[16] fmSusLevels_;
    StkFloat[32] fmAttTimes_;

}

