#include "..\script_component.hpp"
/*
 * Author: PabstMirror
 * Shows real azimuth and elevation on hud
 *
 * Arguments:
 * 0: PFEH Args <ARRAY>
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [[...]] call ace_artillerytables_fnc_turretPFEH
 *
 * Public: No
 */

(_this select 0) params ["_vehicle", "_turret", "_fireModes", "_useAltElevation", "_turretAnimBody", "_invalidGunnerMem", "_elevationMode"];

if (shownArtilleryComputer && {GVAR(disableArtilleryComputer)}) then {
    _whitelistArtilleryComputerArr = [];
    // Break down string from CBA setting EDITBOX into an array.
    if (typeName GVAR(whitelistArtilleryComputer) == "STRING") then {
          _whitelistArtilleryComputerArr = GVAR(whitelistArtilleryComputer) splitString ",";
    };
    // If classname of player's veghicle is in whitelist. Do not close Dialog.
    if ({typeOf vehicle _vehicle == _x} count _whitelistArtilleryComputerArr < 1) then
    {
        // Still Don't like this solution, but it works
        closeDialog 0;
        [localize LSTRING(disableArtilleryComputer_displayName)] call EFUNC(common,displayTextStructured);
    };
};

// Restart display if null (not just at start, this will happen periodicly)
if (isNull (uiNamespace getVariable [QGVAR(display), displayNull])) then {
    TRACE_1("creating display",_this);
    ([QGVAR(modeDisplay)] call BIS_fnc_rscLayer) cutRsc [QGVAR(modeDisplay), "PLAIN", 1, false];
};

private _ctrlGroup = (uiNamespace getVariable [QGVAR(display), displayNull]) displayCtrl 1000;

if (_elevationMode == 0) then {
    // For turrets not using an elevation mode (i.e. mouse controls elevation instead of pageUp/Down)
    // Show the info 1 step below, so it doesn't block vanilla ranging (discreteDistance)
    // vanilla zeroing will have a negative effect, so it's best to range as low as possible
    private _safeZoneGrid = (((safeZoneW / safeZoneH) min 1.2) / 1.2) / 25;
    private _y = 3.5 * _safeZoneGrid + (profileNamespace getVariable ['IGUI_GRID_WEAPON_Y', safeZoneY + 0.5 * _safeZoneGrid]);
    _ctrlGroup ctrlSetPositionY _y;
    _ctrlGroup ctrlCommit 0;
};

// Need to be in gunner mode, so we can check where the optics are aiming at
// However, if there are no optics, ignore the above
if (!_invalidGunnerMem && {cameraView != "GUNNER"}) exitWith {
    _ctrlGroup ctrlShow false;
};
_ctrlGroup ctrlShow true;

BEGIN_COUNTER(pfeh);

private _currentFireMode = (weaponState [_vehicle, _turret]) select 2;
private _currentChargeMode = _fireModes find _currentFireMode;

private _lookVector = (AGLToASL (positionCameraToWorld [0,0,0])) vectorFromTo (AGLToASL (positionCameraToWorld [0,0,1]));
private _weaponDir = _vehicle weaponDirection (currentWeapon _vehicle);

// Calc real azimuth/elevation
// (looking at the sky VS looking at ground will radicaly change fire direction because BIS)
private _display = uiNamespace getVariable ["ACE_dlgArtillery", displayNull];
private _useRealWeaponDir = if ((isNull (_display displayCtrl 173)) || {(_vehicle ammo (currentWeapon _vehicle)) == 0}) then {
    // With no ammo, distance display will be empty, but gun will still fire at wonky angle if aimed at ground
    private _testSeekerPosASL = AGLToASL (positionCameraToWorld [0,0,0]);
    private _testPoint = _testSeekerPosASL vectorAdd (_lookVector vectorMultiply viewDistance);
    !((terrainIntersectASL [_testSeekerPosASL, _testPoint]) || {lineIntersects [_testSeekerPosASL, _testPoint, _vehicle]});
} else {
    ((ctrlText (_display displayCtrl 173)) == "--")
};

private _realElevation = asin (_weaponDir select 2);
private _realAzimuth = 0;
if (_useRealWeaponDir || _invalidGunnerMem) then {
    // No range (looking at sky), it will follow weaponDir:
    _realAzimuth = (_weaponDir select 0) atan2 (_weaponDir select 1)
} else {
    // Valid range, will fire at camera dir
    // Azimuth will still be look dir EVEN IF elevation has flipped over 90! (on steep hills)
    _realAzimuth = ((_lookVector select 0) atan2 (_lookVector select 1));
    if (_useAltElevation) then {
        // Some small mortars have odd launch angles (I think due to the addition of neutral elevation constant with the manual elevation)
        // This gets very close, (should be less than 0.5deg deviation on a 20deg slope)
        private _currentTraverseRad = _vehicle animationSourcePhase _turretAnimBody;
        if (isNil "_currentTraverseRad") then { _currentTraverseRad = _vehicle animationPhase _turretAnimBody; };
        // Get turret roatation around it's z axis, then calc weapon elev in it's projection
        private _turretRot = [vectorDir _vehicle, vectorUp _vehicle, deg _currentTraverseRad] call CBA_fnc_vectRotate3D;
        _realElevation = (acos ((_turretRot vectorCos _weaponDir) min 1)) + ((_turretRot call CBA_fnc_vect2polar) select 2);
        if (_realElevation > 90) then { _realElevation = 180 - _realElevation; }; // does not flip azimuth!
    };
};
if (_realAzimuth < 0) then { _realAzimuth = _realAzimuth + 360; }; // mils will be 0-6400

private _ctrlCharge = (uiNamespace getVariable [QGVAR(display), displayNull]) displayCtrl IDC_CHARGE;
private _ctrlAzimuth = (uiNamespace getVariable [QGVAR(display), displayNull]) displayCtrl IDC_AZIMUTH;
private _ctrlElevation = (uiNamespace getVariable [QGVAR(display), displayNull]) displayCtrl IDC_ELEVATION;

_ctrlAzimuth ctrlSetText format ["AZ: %1", [DEGTOMILS * _realAzimuth, 4, 0] call CBA_fnc_formatNumber];
_ctrlElevation ctrlSetText format ["EL: %1", [DEGTOMILS * _realElevation, 4, 0] call CBA_fnc_formatNumber];
_ctrlCharge ctrlSetText format ["CH: %1", _currentChargeMode];

// avalible for other addons (mk6)
GVAR(predictedAzimuth) = _realAzimuth;
GVAR(predictedElevation) = _realElevation;

END_COUNTER(pfeh);
