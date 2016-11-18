module stk.adsr;

import stk.stk;
import stk.generator;

/***************************************************/
/*! \class ADSR
\brief STK ADSR envelope class.

This class implements a traditional ADSR (Attack, Decay, Sustain,
Release) envelope.  It responds to simple keyOn and keyOff
messages, keeping track of its state.  The \e state = ADSR::IDLE
before being triggered and after the envelope value reaches 0.0 in
the ADSR::RELEASE state.  All rate, target and level settings must
be non-negative.  All time settings are in seconds and must be
positive.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

class ADSR : Generator
{
public:

    //! ADSR envelope states.
    enum : int {
        ATTACK,   /*!< Attack */
        DECAY,    /*!< Decay */
        SUSTAIN,  /*!< Sustain */
        RELEASE,  /*!< Release */
        IDLE      /*!< Before attack / after release */
    }

    //! Default constructor.
    this () {
        target_ = 0.0;
        value_ = 0.0;
        attackRate_ = 0.001;
        decayRate_ = 0.001;
        releaseRate_ = 0.005;
        releaseTime_ = -1.0;
        sustainLevel_ = 0.5;
        state_ = IDLE;
        Stk.addSampleRateAlert(this);
    }

    //! Class destructor.
    ~this() {
        Stk.removeSampleRateAlert(this);
    }

    //! Set target = 1, state = \e ADSR::ATTACK.
    void keyOn() {
        if ( target_ <= 0.0 ) 
            target_ = 1.0;
        state_ = ATTACK;
    }

    //! Set target = 0, state = \e ADSR::RELEASE.
    void keyOff() {
        target_ = 0.0;
        state_ = RELEASE;

        // FIXED October 2010 - Nick Donaldson
        // Need to make release rate relative to current value!!
        // Only update if we have set a TIME rather than a RATE,
        // in which case releaseTime_ will be -1
        if ( releaseTime_ > 0.0 )
            releaseRate_ = value_ / ( releaseTime_ * Stk.sampleRate() );
    }

    //! Set the attack rate (gain / sample).
    void setAttackRate( StkFloat rate ) {
        assert(rate >= 0);
        attackRate_ = rate;
    }

    //! Set the target value for the attack (default = 1.0).
    void setAttackTarget( StkFloat target ) {
        assert(target >= 0);
        target_ = target;
    }

    //! Set the decay rate (gain / sample).
    void setDecayRate( StkFloat rate ) {
        decayRate_ = rate;
    }

    //! Set the sustain level.
    void setSustainLevel( StkFloat level ) {
        sustainLevel_ = level;
    }

    //! Set the release rate (gain / sample).
    void setReleaseRate( StkFloat rate ) {
        releaseRate_ = rate;

        // Set to negative value so we don't update the release rate on keyOff()
        releaseTime_ = -1.0;
    }

    //! Set the attack rate based on a time duration (seconds).
    void setAttackTime( StkFloat time ) {
        attackRate_ = 1.0 / ( time * Stk.sampleRate() );
    }

    //! Set the decay rate based on a time duration (seconds).
    void setDecayTime( StkFloat time ) {
        decayRate_ = (1.0 - sustainLevel_) / ( time * Stk.sampleRate() );
    }

    //! Set the release rate based on a time duration (seconds).
    void setReleaseTime( StkFloat time ) {
        releaseRate_ = sustainLevel_ / ( time * Stk.sampleRate() );
        releaseTime_ = time;
    }

    //! Set sustain level and attack, decay, and release time durations (seconds).
    void setAllTimes( StkFloat aTime, StkFloat dTime, StkFloat sLevel, StkFloat rTime ) {
        this.setAttackTime( aTime );
        this.setSustainLevel( sLevel );
        this.setDecayTime( dTime );
        this.setReleaseTime( rTime );
    }

    //! Set a sustain target value and attack or decay from current value to target.
    void setTarget( StkFloat target ) {
        target_ = target;
        this.setSustainLevel( target_ );
        if ( value_ < target_ ) state_ = ATTACK;
        if ( value_ > target_ ) state_ = DECAY;
    }

    //! Return the current envelope \e state (ATTACK, DECAY, SUSTAIN, RELEASE, IDLE).
    int getState() const {
        return state_;
    }

    //! Set to state = ADSR::SUSTAIN with current and target values of \e value.
    void setValue( StkFloat value ) {
        state_ = SUSTAIN;
        target_ = value;
        value_ = value;
        this.setSustainLevel( value );
        lastFrame_[0] = value;
    }

    //! Return the last computed output value.
    StkFloat lastOut() const { return lastFrame_[0]; };

    //! Compute and return one output sample.
    StkFloat tick() {
        switch ( state_ ) {

            case ATTACK:
                value_ += attackRate_;
                if ( value_ >= target_ ) {
                    value_ = target_;
                    target_ = sustainLevel_;
                    state_ = DECAY;
                }
                lastFrame_[0] = value_;
                break;

            case DECAY:
                if ( value_ > sustainLevel_ ) {
                    value_ -= decayRate_;
                    if ( value_ <= sustainLevel_ ) {
                        value_ = sustainLevel_;
                        state_ = SUSTAIN;
                    }
                }
                else {
                    value_ += decayRate_; // attack target < sustain level
                    if ( value_ >= sustainLevel_ ) {
                        value_ = sustainLevel_;
                        state_ = SUSTAIN;
                    }
                }
                lastFrame_[0] = value_;
                break;

            case RELEASE:
                value_ -= releaseRate_;
                if ( value_ <= 0.0 ) {
                    value_ = 0.0;
                    state_ = IDLE;
                }
                lastFrame_[0] = value_;
                break;
            default:
                break;

        }

        return value_;
    }

    //! Fill a channel of the StkFrames object with computed outputs.
    /*!
    The \c channel argument must be less than the number of
    channels in the StkFrames argument (the first channel is specified
    by 0).  However, range checking is only performed if _STK_DEBUG_
    is defined during compilation, in which case an out-of-range value
    will trigger an StkError exception.
    */
    ref StkFrames tick( ref StkFrames frames, uint channel = 0 ) {
        StkFloat *samples = &frames[channel];
        uint hop = frames.channels();
        for ( uint i=0; i < frames.frames(); i++, samples += hop )
            *samples = tick();
        return frames;
    }

protected:

    override void sampleRateChanged( StkFloat newRate, StkFloat oldRate ) {
        if ( !ignoreSampleRateChange_ ) {
            attackRate_ = oldRate * attackRate_ / newRate;
            decayRate_ = oldRate * decayRate_ / newRate;
            releaseRate_ = oldRate * releaseRate_ / newRate;
        }
    }

    int state_;
    StkFloat value_;
    StkFloat target_;
    StkFloat attackRate_;
    StkFloat decayRate_;
    StkFloat releaseRate_;
    StkFloat releaseTime_;
    StkFloat sustainLevel_;
}
