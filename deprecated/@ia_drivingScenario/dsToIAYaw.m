function iaYaw = dsToIAYaw(dsYaw)
%DSTOIA Convert DSD/ML yaw to IA yaw

% 180 is a flipping point between +/-
% 179 works, but -179 doesn't, try a conditional
% So we can normalize to 0-360
% e.g. 179 -> 179
%     -179 -> 181
if dsYaw < 0
    iaYaw = 360 - abs(dsYaw);
else
    iaYaw = dsYaw + 180;
end

end

