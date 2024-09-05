function iaCoordinates = dsToIA(dsCoordinates)
%DSTOIA Convert DSD/ML coordinates to IA coordinates

    % leave room to use scenario.coordinatetransform
    % in case there isn't a reversal
    iaCoordinates(1) = 1 * dsCoordinates(1);
    iaCoordinates(2) = 1 * dsCoordinates(2);
    iaCoordinates(3) = dsCoordinates(3);
end

