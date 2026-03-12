FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY ["nem.Gateway/nem.Gateway.csproj", "nem.Gateway/"]
RUN dotnet restore "nem.Gateway/nem.Gateway.csproj"

COPY ["nem.Gateway/", "nem.Gateway/"]
WORKDIR /src/nem.Gateway
RUN dotnet publish "nem.Gateway.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app/nem.Gateway

ENV GATEWAY_PORT=8090

COPY --from=build /app/publish ./

EXPOSE 8090

ENTRYPOINT ["dotnet", "nem.Gateway.dll"]
