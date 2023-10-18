%% explain 
%
% explain things
%

function [arg1, arg2]=testfunction(var)

     if nargout >1
         arg1=var*2;
         arg2=var*4;
     else 
        arg1=var*3;
     end
    
    
end