function coflows = convertTimes2ms(coflows)

time_unit = 1e-3;

for c = coflows
    c.arrival = ceil(c.arrival/time_unit);
    c.deadline = ceil(c.deadline/time_unit);
end

end